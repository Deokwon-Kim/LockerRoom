import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/login/login_page.dart';
import 'package:lockerroom/provider/social_login_provider.dart';
import 'package:lockerroom/services/navigation_service.dart';
import 'package:lockerroom/main.dart';
import 'package:provider/provider.dart';

class SocialLoginPage extends StatelessWidget {
  const SocialLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                        builder: (context) => Center(
                          child: CircularProgressIndicator(color: BUTTON),
                        ),
                      );

                      await socialProvider.googleLogin();

                      // navigatorKey를 사용하여 다이얼로그 확실히 닫기
                      navigatorKey.currentState?.pop();

                      // AuthWrapper로 명시적으로 이동 (authStateChanges가 발생하지 않을 수 있으므로)
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const AuthWrapper(),
                          ),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      print('구글 로그인 실패: $e');
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
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(8),
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
                      borderRadius: BorderRadius.circular(8),
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
                      borderRadius: BorderRadius.circular(8),
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
                    try {
                      // 로딩 표시
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => Center(
                          child: CircularProgressIndicator(color: BUTTON),
                        ),
                      );

                      await socialProvider.kakaoLogin();

                      // navigatorKey를 사용하여 다이얼로그 확실히 닫기
                      navigatorKey.currentState?.pop();

                      // AuthWrapper로 명시적으로 이동 (authStateChanges가 발생하지 않을 수 있으므로)
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const AuthWrapper(),
                          ),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      print('카카오 로그인 실패 :$e');
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
                      borderRadius: BorderRadius.circular(8),
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
