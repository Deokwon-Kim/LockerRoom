import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/main.dart';
import 'package:lockerroom/page/intution_record/intution_record_list_page.dart';
import 'package:lockerroom/page/team_select_page.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/market_feed_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: WHITE,
      appBar: AppBar(
        backgroundColor: WHITE,
        centerTitle: true,
        title: Text(
          '설정',
          style: TextStyle(
            color: GRAYSCALE_LABEL_950,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {},
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Column(
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, 'changeNickname');
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '닉네임 변경',
                              style: TextStyle(
                                color: GRAYSCALE_LABEL_950,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.pushNamed(context, 'changeNickname');
                              },
                              icon: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: GRAYSCALE_LABEL_950,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, 'changePassword');
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '비밀번호 변경',
                              style: TextStyle(
                                color: GRAYSCALE_LABEL_950,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.pushNamed(context, 'changePassword');
                              },
                              icon: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: GRAYSCALE_LABEL_950,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final changed = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  TeamSelectPage(isChanging: true),
                            ),
                          );

                          toastification.show(
                            context: context,
                            type: ToastificationType.success,
                            alignment: Alignment.bottomCenter,
                            autoCloseDuration: const Duration(seconds: 2),
                            title: Text('팀이 변경되었습니다: $changed'),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '응원팀 변경',
                              style: TextStyle(
                                color: GRAYSCALE_LABEL_950,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                final changed = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TeamSelectPage(isChanging: true),
                                  ),
                                );

                                toastification.show(
                                  context: context,
                                  type: ToastificationType.success,
                                  alignment: Alignment.bottomCenter,
                                  autoCloseDuration: const Duration(seconds: 2),
                                  title: Text('팀이 변경되었습니다: $changed'),
                                );
                              },
                              icon: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: GRAYSCALE_LABEL_950,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: GRAYSCALE_LABEL_50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 30.0, right: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '버전',
                      style: TextStyle(
                        color: GRAYSCALE_LABEL_950,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '1.0.0',
                      style: TextStyle(
                        color: GRAYSCALE_LABEL_950,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {},
              child: Container(
                width: double.infinity,
                height: 368,
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Column(
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, 'noticeList');
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '공지사항',
                              style: TextStyle(
                                color: GRAYSCALE_LABEL_950,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.pushNamed(context, 'noticeList');
                              },
                              icon: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: GRAYSCALE_LABEL_950,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => IntutionRecordListPage(),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '직관기록',
                              style: TextStyle(
                                color: GRAYSCALE_LABEL_950,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        IntutionRecordListPage(),
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: GRAYSCALE_LABEL_950,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, 'customerCenter');
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '고객센터',
                              style: TextStyle(
                                color: GRAYSCALE_LABEL_950,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.pushNamed(context, 'customerCenter');
                              },
                              icon: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: GRAYSCALE_LABEL_950,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, 'terms');
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '이용약관',
                              style: TextStyle(
                                color: GRAYSCALE_LABEL_950,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.pushNamed(context, 'terms');
                              },
                              icon: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: GRAYSCALE_LABEL_950,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, 'policy');
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '개인정보 처리방침',
                              style: TextStyle(
                                color: GRAYSCALE_LABEL_950,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.pushNamed(context, 'policy');
                              },
                              icon: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: GRAYSCALE_LABEL_950,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          // 로그아웃 전에 모든 실시간 구독 해제
                          try {
                            context
                                .read<CommentProvider>()
                                .cancelAllSubscriptions();
                          } catch (_) {}
                          try {
                            context
                                .read<FeedProvider>()
                                .cancelAllSubscriptions();
                          } catch (_) {}
                          try {
                            context
                                .read<MarketFeedProvider>()
                                .cancelAllSubscriptions();
                          } catch (_) {}
                          try {
                            context
                                .read<ProfileProvider>()
                                .cancelAllSubscriptions();
                          } catch (_) {}

                          await userProvider.signOut();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AuthWrapper(),
                            ),
                            (route) => false,
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '로그아웃',
                              style: TextStyle(
                                color: RED_DANGER_TEXT_50,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
