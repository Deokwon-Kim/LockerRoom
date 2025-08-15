import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/const/custome_button.dart';
import 'package:lockerroom/page/team_select_page.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_checkFields);
    _passwordController.addListener(_checkFields);
  }

  @override
  void dispose() {
    _emailController.removeListener(_checkFields);
    _passwordController.removeListener(_checkFields);
    super.dispose();
  }

  void _checkFields() {
    setState(() {
      _isButtonEnabled =
          _emailController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty;
    });
  }

  // 로그인 함수
  Future<void> _signIn() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );

      debugPrint('로그인 성공: ${userCredential.user}');

      // UserProvider 업데이트
      userProvider.initializeUser();
      if (userCredential.user != null) {
        userProvider.startListeningUserDoc(userCredential.user!.uid);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TeamSelectPage()),
      );
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code}');
      switch (e.code) {
        case 'invalid-credential':
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.flat,
            alignment: Alignment.bottomCenter,
            autoCloseDuration: Duration(seconds: 2),
            title: Text("잘못된 이메일 또는 비밀번호입니다."),
          );
          break;
        default:
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.flat,
            alignment: Alignment.bottomCenter,
            autoCloseDuration: Duration(seconds: 2),
            title: Text("로그인 실패 ${e.message.toString()}"),
          );
      }
    } catch (e) {
      print('로그인 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // final userProvider = Provider.of<UserProvider>(context);
    // // final googleUser = userProvider.currentUser;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true, // 키보드 올라올 때 자동 조정
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: IntrinsicHeight(
              child: Column(
                // mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/images/applogo/app_logo.png'),
                  TextFormField(
                    controller: _emailController,
                    cursorColor: BUTTON,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: '이메일',
                      labelStyle: TextStyle(color: Colors.grey),
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
                  SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordController,
                    cursorColor: ORANGE_PRIMARY_500,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      labelStyle: TextStyle(color: Colors.grey),
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
                  SizedBox(height: 20),
                  GestureDetector(
                    onTap: _isButtonEnabled ? _signIn : null,

                    child: Container(
                      alignment: Alignment.center,
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _isButtonEnabled ? BUTTON : GRAYSCALE_LABEL_300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '로그인',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '계정이 없으신가요?',
                        style: GoogleFonts.inter(
                          color: GRAYSCALE_LABEL_950,
                          fontSize: 15,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, 'signUp');
                        },
                        style: customTextButtonStyle(),
                        child: Text(
                          '회원가입',
                          style: TextStyle(
                            color: BUTTON,
                            fontSize: 15.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, 'findPassword');
                        },
                        style: customTextButtonStyle(),
                        child: Text(
                          '비밀번호 찾기',
                          style: TextStyle(
                            color: GRAYSCALE_LABEL_700,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // GestureDetector(
                  //   onTap: () async {
                  //     await userProvider.googleLogin();

                  //     Navigator.pushReplacement(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (context) => TeamSelectPage(),
                  //       ),
                  //     );
                  //   },
                  //   child: Container(
                  //     width: double.infinity,
                  //     height: 58,
                  //     decoration: BoxDecoration(
                  //       color: GRAYSCALE_LABEL_50,
                  //       border: Border.all(color: Colors.black),
                  //       borderRadius: BorderRadius.circular(12),
                  //     ),
                  //     child: Row(
                  //       mainAxisAlignment: MainAxisAlignment.center,
                  //       children: [
                  //         Image.asset(
                  //           'assets/images/google_icon.png',
                  //           height: 30,
                  //         ),
                  //         SizedBox(width: 10),
                  //         Text(
                  //           'Google 계정으로 로그인',
                  //           style: TextStyle(
                  //             color: Colors.black,
                  //             fontSize: 15,
                  //             fontWeight: FontWeight.bold,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
