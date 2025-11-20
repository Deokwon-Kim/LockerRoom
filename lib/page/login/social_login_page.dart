import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/login/login_page.dart';
import 'package:lockerroom/provider/social_login_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';

class SocialLoginPage extends StatelessWidget {
  const SocialLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final socialProvider = context.read<SocialLoginProvider>();
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      body: Stack(
        children: [
          Image.asset(
            'assets/images/IMG_4325.jpg',
            fit: BoxFit.cover,
            height: screenHeight,
          ),
          Container(height: screenHeight, color: Colors.black.withOpacity(0.2)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image.asset('assets/images/logo/app_logo_NoneBack.png'),
                // Text('더베이스에 오신걸 환영합니다'),
                //구글 로그인
                GestureDetector(
                  onTap: () async {
                    try {
                      // 로딩 표시
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) =>
                            Center(child: CircularProgressIndicator()),
                      );

                      await userProvider.googleLogin();

                      // 로딩 닫기
                      if (context.mounted) {
                        Navigator.pop(context);
                      }

                      // 성공 시 화면 이동
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BottomTabBar(),
                          ),
                        );
                      }
                    } catch (e) {
                      // 로딩 닫기
                      if (context.mounted) {
                        Navigator.pop(context);
                      }

                      // 에러 메시지 표시
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('로그인에 실패했습니다. 다시 시도해주세요.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      print('구글 로그인 에러: $e');
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/logo/google.png',
                          height: 20,
                        ),
                        Text(
                          '구글로 시작하기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Color(0xff1178F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/logo/facebook.png',
                          height: 30,
                        ),
                        SizedBox(width: 10),
                        Text(
                          '페이스북으로 시작하기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: WHITE,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      color: BLACK,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/logo/apple.jpg', height: 30),
                        Text(
                          '애플로 시작하기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: WHITE,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    Center(child: CircularProgressIndicator());
                    try {
                      await socialProvider.kakaoLogin();

                      if (context.mounted) {
                        Navigator.pop(context);
                      }

                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null) return;

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .get();

                      if (!context.mounted) return;
                    } catch (e) {
                      print('카카오 로그인 실패 :$e');
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: Image.asset(
                    'assets/images/kakao_login_large_wide.png',
                    height: 58,
                    width: double.infinity,
                  ),
                ),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 1,
                      color: const Color.fromARGB(255, 2, 2, 2),
                    ),
                    SizedBox(width: 10),
                    Text('OR'),
                    SizedBox(width: 10),
                    Container(
                      width: 150,
                      height: 1,
                      color: const Color.fromARGB(255, 2, 2, 2),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.email),
                        SizedBox(width: 10),
                        Text(
                          '이메일로 시작하기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
