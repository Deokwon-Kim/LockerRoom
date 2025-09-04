import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/firebase_options.dart';
import 'package:lockerroom/login/login_page.dart';
import 'package:lockerroom/login/signup_page.dart';
import 'package:lockerroom/page/setting/setting_page.dart';
import 'package:lockerroom/page/team_select_page.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/market_upload_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/upload_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:lockerroom/provider/video_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'lib/api_key/youtube_key.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TeamProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => UploadProvider()),
        ChangeNotifierProvider(create: (context) => FeedProvider()),
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
        ChangeNotifierProvider(create: (context) => VideoProvider()),
        ChangeNotifierProvider(create: (context) => CommentProvider()),
        ChangeNotifierProvider(create: (context) => MarketUploadProvider()),
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
          'setting': (context) => const SettingPage(),
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
          //사용자 정보를 UserProvider에 로드
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<UserProvider>(context, listen: false).loadNickname();
          });
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: BUTTON));
        } else if (snapshot.hasError) {
          return const Center(child: Text('에러가 발생하였습니다.'));
        } else if (snapshot.hasData) {
          final user = snapshot.data!;
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: BUTTON),
                );
              }
              if (userSnap.hasError) {
                return const Center(child: Text('유저 정보를 불러오지 못했습니다.'));
              }

              final data = userSnap.data?.data() ?? {};
              final savedTeamName = data['team'] as String?;

              if (savedTeamName != null && savedTeamName.isNotEmpty) {
                // Provider에 선택 팀 반영 (TeamModel 매핑)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final teamProvider = Provider.of<TeamProvider>(
                    context,
                    listen: false,
                  );
                  // 문자열 상태도 유지
                  teamProvider.setTeam(savedTeamName);
                  // TeamModel 찾아서 선택
                  final list = teamProvider.getTeam('team');
                  final match = list.firstWhere(
                    (t) => t.name == savedTeamName,
                    orElse: () => list.first,
                  );
                  teamProvider.selectTeam(match);
                });
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
