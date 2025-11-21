import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:lockerroom/provider/social_login_provider.dart';
import 'package:lockerroom/provider/feed_provider.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/market_feed_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/notification_provider.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lockerroom/main.dart';

class CustormerCenterPage extends StatelessWidget {
  const CustormerCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final up = context.read<UserProvider>();
    return Scaffold(
      backgroundColor: WHITE,
      appBar: AppBar(
        backgroundColor: WHITE,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '고객센터',
          style: TextStyle(
            color: GRAYSCALE_LABEL_950,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: GRAYSCALE_LABEL_50,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSettingItem(
                text: '1:1 문의하기',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return ConfirmationDialog(
                        title: '1:1 문의하기',
                        content: '이메일로 전송됩니다.\n문의 내용을 작성해주세요.',
                        confirmText: '메일 작성',
                        cancelText: '취소',
                        onConfirm: () {
                          sendInquiryEmail(
                            'MyWay 1:1 문의',
                            '안녕하세요, 더베이스 팀 입니다.\n\n문의 내용을 작성해주세요 :)',
                          );
                        },
                      );
                    },
                  );
                },
              ),
              _buildSettingItem(
                text: '회원탈퇴',

                onTap: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  final providers =
                      user?.providerData.map((p) => p.providerId).toList() ??
                      [];
                  final isKakaoUser = providers.contains('oidc.thebase');
                  final isGoogleUser = providers.contains('google.com');
                  final isAppleUser = providers.contains('apple.com');

                  String? password;
                  // 이메일 로그인 사용자만 비밀번호 입력 필요
                  if (!isKakaoUser && !isGoogleUser && !isAppleUser) {
                    password = await _showPasswordDialog(context);
                    if (password == null || password.isEmpty) return;
                  }

                  try {
                    // print('=== 회원탈퇴 시작: 모든 구독 취소 ===');

                    // 1. 모든 실시간 구독 취소 (권한 에러 방지)
                    try {
                      context.read<CommentProvider>().cancelAllSubscriptions();
                      // print('✓ CommentProvider 구독 취소됨');
                    } catch (_) {}

                    try {
                      context.read<FeedProvider>().cancelAllSubscriptions();
                      // print('✓ FeedProvider 구독 취소됨');
                    } catch (_) {}

                    try {
                      context.read<CommentProvider>().cancelAllSubscriptions();
                      context.read<FeedProvider>().cancelAllSubscriptions();
                      context
                          .read<MarketFeedProvider>()
                          .cancelAllSubscriptions();
                      context.read<ProfileProvider>().cancelAllSubscriptions();
                      context.read<NotificationProvider>().cancel();
                      context.read<BlockProvider>().cancel();

                      // 로그인 방식에 따라 적절한 탈퇴 메서드 호출
                      if (isKakaoUser) {
                        await up.deleteKakaoAccount();
                      } else if (isGoogleUser) {
                        // 구글 로그인: SocialLoginProvider의 deleteGoogleAccount 호출
                        // 참고: Firestore 데이터 삭제는 수동으로 처리 필요 (UserProvider의 _deleteUserData는 private)
                        await context
                            .read<SocialLoginProvider>()
                            .deleteGoogleAccount();
                      } else if (isAppleUser) {
                        await context
                            .read<SocialLoginProvider>()
                            .deleteAppleAccount();
                      } else {
                        await up.deleteEmailAccount(password!);
                      }

                      toastification.show(
                        context: context,
                        type: ToastificationType.success,
                        alignment: Alignment.bottomCenter,
                        autoCloseDuration: Duration(seconds: 2),
                        title: Text('회원 탈퇴 완료'),
                      );

                      // 3. AuthWrapper로 돌아가기
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const AuthWrapper(),
                          ),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      // print('회원탈퇴 에러: $e');
                      toastification.show(
                        context: context,
                        type: ToastificationType.error,
                        alignment: Alignment.bottomCenter,
                        autoCloseDuration: Duration(seconds: 2),
                        title: Text('회원 탈퇴 실패: ${e.toString()}'),
                      );
                    }

                    // print('✓ BlockProvider 구독 취소됨');
                  } catch (_) {}
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _showPasswordDialog(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: WHITE,
      title: Text('비밀번호 확인', style: TextStyle(fontSize: 15)),
      content: TextField(
        autofocus: true,
        controller: controller,
        obscureText: true,
        decoration: InputDecoration(
          labelText: '비밀번호를 입력하세요',
          labelStyle: TextStyle(color: BUTTON),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BUTTON, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BUTTON, width: 1.5),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('취소', style: TextStyle(color: Colors.black)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: BUTTON,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text('확인', style: TextStyle(color: WHITE)),
        ),
      ],
    ),
  );
}

Widget _buildSettingItem({required String text, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      height: 60,
      padding: const EdgeInsets.only(left: 20, right: 20),
      decoration: BoxDecoration(
        color: GRAYSCALE_LABEL_50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: text == '회원탈퇴' ? RED_DANGER_TEXT_50 : GRAYSCALE_LABEL_900,
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
    ),
  );
}

void sendInquiryEmail(String title, String body) async {
  final Uri emailUri = Uri(
    scheme: 'mailto',
    path: 'khjs7878@naver.com',
    query: Uri.encodeFull('subject=$title&body=$body'),
  );

  if (await canLaunchUrl(emailUri)) {
    await launchUrl(emailUri);
  } else {
    throw '메일 앱을 열 수 없습니다.';
  }
}
