import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/firebase_options.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/login/login_page.dart';
import 'package:lockerroom/login/signup_page.dart';
import 'package:lockerroom/page/team_select_page.dart';
import 'package:lockerroom/provider/bottom_tab_bar_provider.dart';
import 'package:lockerroom/provider/post_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TeamProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => PostProvider()),
        ChangeNotifierProvider(create: (context) => BottomTabBarProvider()),
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Demo',
        home: const AuthWrapper(),
        routes: {
          'signUp': (context) => const SignupPage(),
          'signIn': (context) => const LoginPage(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        print('AuthWrapper - ConnectionState: ${snapshot.connectionState}');
        print('AuthWrapper - HasData: ${snapshot.hasData}');
        print('AuthWrapper - HasError: ${snapshot.hasError}');
        if (snapshot.hasData) {
          print('AuthWrapper - Current User: ${snapshot.data?.uid}');
          // 사용자 정보를 UserProvider에 초기화하고 프로필 스트림 구독 시작
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final user = snapshot.data!;
            final userProvider = context.read<UserProvider>();
            userProvider.initializeUser();
            userProvider.startListeningUserDoc(user.uid);
          });
        } else {
          // 비인증 상태에서는 스트림 구독 해제 및 사용자 정보 초기화
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<UserProvider>().stopListeningUserDoc();
            context.read<UserProvider>().clearUserData();
          });
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Eagles));
        } else if (snapshot.hasError) {
          return const Center(child: Text('에러가 발생하였습니다.'));
        } else if (snapshot.hasData) {
          final uid = snapshot.data!.uid;
          // 사용자 문서를 조회해 선호팀 여부에 따라 초기 라우팅 분기
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get(),
            builder: (context, userDocSnap) {
              if (userDocSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Eagles),
                );
              }
              final data = userDocSnap.data?.data();
              final favoriteTeam = data != null
                  ? data['favoriteTeam'] as String?
                  : null;
              if (favoriteTeam != null && favoriteTeam.isNotEmpty) {
                // 선호팀이 있으면 바로 하단탭으로
                return const BottomTabBar();
              } else {
                return const TeamSelectPage();
              }
            },
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
