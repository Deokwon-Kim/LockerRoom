import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:toastification/toastification.dart';

class FindPasswordPage extends StatefulWidget {
  const FindPasswordPage({super.key});

  @override
  State<FindPasswordPage> createState() => _FindPasswordPageState();
}

class _FindPasswordPageState extends State<FindPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool isValid = false;
  String label = '';

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();

    RegExp emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      if (mounted) {
        setState(() {
          label = "유효하지 않은 이메일 형식입니다.";
        });
      }
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          title: Text('비밀번호 재설정 이메일이 전송되었습니다.'),
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          title: Text('이메일 전송 실패: ${e.toString()}'),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double horizontalPageMargin = 20.0;
    const double fieldHeight = 52.0;
    const double borderRadiusValue = 8.0;

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          icon: Icon(Icons.arrow_back_ios, color: GRAYSCALE_LABEL_950),
        ),
        title: Text(
          '비밀번호 찾기',
          style: TextStyle(
            color: GRAYSCALE_LABEL_950,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: horizontalPageMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 30),
              Text(
                '이메일 주소 입력',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: GRAYSCALE_LABEL_900,
                ),
              ),
              SizedBox(height: 5),
              SizedBox(
                height: fieldHeight,
                child: TextField(
                  cursorColor: ORANGE_PRIMARY_500,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    setState(() {
                      isValid = value.trim().isNotEmpty;
                      label = '';
                    });
                  },
                  decoration: InputDecoration(
                    hintText: '비밀번호 재설정 링크를 받을 이메일을 입력하세요',
                    hintStyle: TextStyle(
                      color: GRAYSCALE_LABEL_500,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: WHITE,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(borderRadiusValue),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(borderRadiusValue),
                      borderSide: BorderSide(
                        color: GRAYSCALE_LABEL_400,
                        width: 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(borderRadiusValue),
                      borderSide: BorderSide(
                        color: GRAYSCALE_LABEL_700,
                        width: 1.0,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: (fieldHeight - 20) / 2,
                    ),
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(color: GRAYSCALE_LABEL_800, fontSize: 14),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: fieldHeight,
                child: ElevatedButton(
                  onPressed: () {
                    isValid ? _sendPasswordResetEmail() : null;
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? BUTTON : GRAYSCALE_LABEL_300,
                    foregroundColor: GRAYSCALE_LABEL_950,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadiusValue),
                    ),
                    elevation: 0,
                    textStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Text('이메일 전송', style: TextStyle(color: WHITE)),
                ),
              ),
              SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
