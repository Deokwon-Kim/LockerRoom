import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/firebase_options.dart';
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final user = snapshot.data!;
            context.read<UserProvider>().initializeUser();
            context.read<UserProvider>().startListeningUserDoc(user.uid);
            context.read<ProfileProvider>().startListening(user.uid);
          });
        } else {
          // 비인증 상태에서는 스트림 구독 해제
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<ProfileProvider>().stopListening();
            context.read<UserProvider>().stopListeningUserDoc();
          });
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Eagles));
        } else if (snapshot.hasError) {
          return const Center(child: Text('에러가 발생하였습니다.'));
        } else if (snapshot.hasData) {
          // return const BottomTabBar();
          return const TeamSelectPage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
