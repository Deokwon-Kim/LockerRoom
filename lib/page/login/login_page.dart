import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/const/custome_button.dart';
import 'package:toastification/toastification.dart';
import 'package:lockerroom/main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isButtonEnabled = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _checkFields() {
    final enabled =
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
    if (enabled != _isButtonEnabled) {
      setState(() {
        _isButtonEnabled = enabled;
      });
    }
  }

  void _showErrorToast(String message) {
    if (!mounted) return;
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flat,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 2),
      title: Text(message),
    );
  }

  // 로그인 함수
  Future<void> _signIn() async {
    if (_isLoading || !_isButtonEnabled) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      debugPrint('로그인 성공: ${userCredential.user}');
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential') {
        _showErrorToast('잘못된 이메일 또는 비밀번호입니다.');
      } else {
        _showErrorToast('로그인 실패 ${e.message ?? e.code}');
      }
    } catch (_) {
      _showErrorToast('로그인 중 오류가 발생했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: GRAYSCALE_LABEL_400,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: WHITE,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      prefixIcon: Icon(prefixIcon, color: GRAYSCALE_LABEL_500, size: 20),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: GRAYSCALE_LABEL_200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BUTTON, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _isButtonEnabled && !_isLoading;
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: GRAYSCALE_LABEL_900,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Image.asset(
                          context.appLogoAsset,
                          height: 112,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '이메일로 로그인',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: GRAYSCALE_LABEL_950,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '가입하신 이메일과 비밀번호를 입력해주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: GRAYSCALE_LABEL_600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        cursorColor: BUTTON,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(
                          fontSize: 15,
                          color: GRAYSCALE_LABEL_950,
                        ),
                        decoration: _buildInputDecoration(
                          hintText: '이메일 주소',
                          prefixIcon: Icons.mail_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        cursorColor: BUTTON,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _signIn(),
                        style: const TextStyle(
                          fontSize: 15,
                          color: GRAYSCALE_LABEL_950,
                        ),
                        decoration: _buildInputDecoration(
                          hintText: '비밀번호',
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: GRAYSCALE_LABEL_500,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: canSubmit ? BUTTON : GRAYSCALE_LABEL_300,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: canSubmit
                              ? [
                                  BoxShadow(
                                    color: BUTTON.withValues(alpha: 0.22),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canSubmit ? _signIn : null,
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        '로그인',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '계정이 없으신가요?',
                            style: TextStyle(
                              color: GRAYSCALE_LABEL_600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '회원가입');
                            },
                            style: customTextButtonStyle(),
                            child: const Text(
                              '회원가입',
                              style: TextStyle(
                                color: BUTTON,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '비밀번호찾기');
                          },
                          style: customTextButtonStyle(),
                          child: const Text(
                            '비밀번호 찾기',
                            style: TextStyle(
                              color: GRAYSCALE_LABEL_600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 16),
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
