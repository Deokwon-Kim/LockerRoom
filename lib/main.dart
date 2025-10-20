import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/firebase_options.dart';
import 'package:lockerroom/page/legal/privacy_policy_page.dart';
import 'package:lockerroom/page/legal/terms_of_service_page.dart';
import 'package:lockerroom/page/login/login_page.dart';
import 'package:lockerroom/page/login/signup_page.dart';
import 'package:lockerroom/page/notice/notice_list_page.dart';
import 'package:lockerroom/page/setting/change_password_page.dart';
import 'package:lockerroom/page/setting/custormer_center_page.dart';
import 'package:lockerroom/page/setting/find_password_page.dart';
import 'package:lockerroom/page/setting/nickname_change_page.dart';
import 'package:lockerroom/page/setting/setting_page.dart';
import 'package:lockerroom/page/alert/notifications_page.dart';
import 'package:lockerroom/page/team_select_page.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/follow_provider.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/intution_record_provider.dart';
import 'package:lockerroom/provider/market_feed_provider.dart';
import 'package:lockerroom/provider/market_upload_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/upload_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:lockerroom/provider/video_provider.dart';
import 'package:lockerroom/repository/user_repository.dart';
import 'package:lockerroom/provider/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:lockerroom/services/notification_service.dart';
import 'package:lockerroom/services/navigation_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // TODO: 백그라운드 수신 처리
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'lib/api_key/youtube_key.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 로컬 알림 초기화
  await NotificationService().initNotification();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ios 권한 요청
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // ios 포그라운드 표시 옵션
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: false,
    badge: false,
    sound: false,
  );

  final apns = await FirebaseMessaging.instance.getAPNSToken();
  print('APNs token: $apns');

  final token = await FirebaseMessaging.instance.getToken();
  print('FCM token: $token');
  // 토큰 저장 및 갱신 반영
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && token != null) {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print('FCM token refreshed: $newToken');
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
        'fcmToken': newToken,
      }, SetOptions(merge: true));
    }
  });

  // 포그라운드 수신 시 로컬 알림 표시
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final n = message.notification;
    if (n != null) {
      // NotificationService().showForegroundNotification(
      //   title: n.title ?? '알림',
      //   body: n.body ?? '',
      //   payload: jsonEncode(message.data),
      // );
    }
  });

  // 앱이 완전 종료된 상태에서 알림을 눌러 시작된 경우 딥링크 처리
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    navigateFromData(initialMessage.data);
  }

  // 백그라운드에서 열었을 때 처리
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    navigateFromData(message.data);
  });

  final repo = UserRepository();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

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
        ChangeNotifierProvider(create: (context) => MarketFeedProvider()),
        ChangeNotifierProvider(create: (context) => IntutionRecordProvider()),
        ChangeNotifierProvider(
          create: (context) => IntutionRecordListProvider(),
        ),
        ChangeNotifierProvider(create: (context) => NotificationProvider()),
        ChangeNotifierProvider(
          create: (context) => FollowProvider(repo, currentUserId ?? ''),
        ),
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
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Flutter Demo',
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
        home: const AuthWrapper(),
        routes: {
          'signUp': (context) => const SignupPage(),
          'signIn': (context) => const LoginPage(),
          'setting': (context) => const SettingPage(),
          'changeNickname': (context) => const NicknameChangePage(),
          'findPassword': (context) => const FindPasswordPage(),
          'notifications': (context) => const NotificationsPage(),
          'customer': (context) => const CustormerCenterPage(),
          'noticeList': (context) => const NoticeListPage(),
          'terms': (context) => const TermsOfServicePage(),
          'policy': (context) => const PrivacyPolicyPage(),
          'changePassword': (context) => const ChangePasswordPage(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.hasData) {
          print('AuthWrapper - Current User: ${snapshot.data?.uid}');
          //사용자 정보를 UserProvider에 로드
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<UserProvider>(context, listen: false).loadNickname();
            // 로그인 후 알림 구독 시작
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              Provider.of<NotificationProvider>(
                context,
                listen: false,
              ).listen(uid);
            }
          });
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: selectedColor));
        } else if (snapshot.hasError) {
          return const Center(child: Text('에러가 발생하였습니다.'));
        } else if (snapshot.hasData) {
          print('AuthWrapper - Current User: ${snapshot.data?.uid}');
          //사용자 정보를 UserProvider에 로드
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<UserProvider>(context, listen: false).loadNickname();
            // 로그인 후 알림 구독 시작
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              Provider.of<NotificationProvider>(
                context,
                listen: false,
              ).listen(uid);
            }
          });
          final user = snapshot.data!;
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: selectedColor),
                );
              }
              if (userSnap.hasError) {
                return const Center(child: Text('유저 정보를 불러오지 못했습니다.'));
              }

              // 사용자 데이터가 없거나 비어있으면 TeamSelectPage로 이동
              if (!userSnap.hasData ||
                  userSnap.data == null ||
                  !userSnap.data!.exists) {
                return const TeamSelectPage();
              }

              final data = userSnap.data?.data() ?? {};
              final savedTeamName = data['team'] as String?;

              if (savedTeamName != null && savedTeamName.isNotEmpty) {
                // Provider에 선택 팀 반영 (TeamModel 매핑)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    final teamProvider = Provider.of<TeamProvider>(
                      context,
                      listen: false,
                    );
                    // 문자열 상태도 유지
                    teamProvider.setTeam(savedTeamName);
                    // TeamModel 찾아서 선택
                    final list = teamProvider.getTeam('team');
                    if (list.isNotEmpty) {
                      final match = list.firstWhere(
                        (t) => t.name == savedTeamName,
                        orElse: () => list.first,
                      );
                      teamProvider.selectTeam(match);
                    }
                  } catch (e) {
                    print('팀 선택 중 에러: $e');
                  }
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
