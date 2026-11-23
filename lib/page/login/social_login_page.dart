import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/login/login_page.dart';
import 'package:lockerroom/provider/social_login_provider.dart';
import 'package:lockerroom/services/navigation_service.dart';
import 'package:lockerroom/main.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class SocialLoginPage extends StatelessWidget {
  const SocialLoginPage({super.key});

  Future<void> _handleSocialLogin(
    BuildContext context, {
    required String method,
    required Future<void> Function() loginAction,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            Center(child: CircularProgressIndicator(color: BUTTON)),
      );

      await loginAction();

      FirebaseAnalytics.instance.logEvent(
        name: 'login',
        parameters: {'method': method},
      );

      navigatorKey.currentState?.pop();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final socialProvider = context.read<SocialLoginProvider>();
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48.0,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      Image.asset(
                        'assets/images/applogo/ilu_app_icon.png',
                        height: 175,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '1루부터 시작하는 야구 일상',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: GRAYSCALE_LABEL_700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(flex: 3),
                      if (Platform.isIOS) ...[
                        _SocialLoginButton(
                          backgroundColor: BLACK,
                          textColor: WHITE,
                          label: '애플로 시작하기',
                          leading: Image.asset(
                            'assets/images/logo/apple.jpg',
                            height: 24,
                          ),
                          onTap: () => _handleSocialLogin(
                            context,
                            method: 'apple',
                            loginAction: socialProvider.signWithApple,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _SocialLoginButton(
                        backgroundColor: WHITE,
                        textColor: GRAYSCALE_LABEL_900,
                        borderColor: GRAYSCALE_LABEL_200,
                        label: '구글로 시작하기',
                        leading: Image.asset(
                          'assets/images/logo/google.png',
                          height: 20,
                        ),
                        onTap: () => _handleSocialLogin(
                          context,
                          method: 'google',
                          loginAction: socialProvider.googleLogin,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SocialLoginButton(
                        backgroundColor: const Color(0xFFFEE500),
                        textColor: const Color(0xFF191919),
                        label: '카카오로 시작하기',
                        leading: Image.asset(
                          'assets/images/logo/kakao.png',
                          height: 24,
                        ),
                        onTap: () => _handleSocialLogin(
                          context,
                          method: 'kakao',
                          loginAction: socialProvider.kakaoLogin,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: GRAYSCALE_LABEL_200,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              '또는',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: GRAYSCALE_LABEL_500,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: GRAYSCALE_LABEL_200,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SocialLoginButton(
                        backgroundColor: WHITE,
                        textColor: GRAYSCALE_LABEL_900,
                        borderColor: GRAYSCALE_LABEL_200,
                        label: '이메일로 시작하기',
                        leading: const Icon(
                          Icons.mail_outline_rounded,
                          size: 20,
                          color: GRAYSCALE_LABEL_800,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final String label;
  final Widget leading;
  final VoidCallback onTap;

  const _SocialLoginButton({
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    required this.label,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
