import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/login/terms_gate_page.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _nicknameFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  bool _isPasswordValid = false;
  bool _isNicknameValid = true;
  bool _isNameValid = true;
  bool _isEmailValid = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String _passwordErrorMessage = '';
  String _nicknameErrorMessage = '';
  String _nameErrorMessage = '';
  String _emailErrorMessage = '';
  String _confirmPasswordErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_onFormChanged);
    _nameController.addListener(_onFormChanged);
    _emailController.addListener(_onFormChanged);
    _passwordController.addListener(_onFormChanged);
    _confirmPasswordController.addListener(_onFormChanged);

    for (final node in [
      _nicknameFocus,
      _nameFocus,
      _emailFocus,
      _passwordFocus,
      _confirmPasswordFocus,
    ]) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    _nicknameFocus.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    _validateNickname();
    _validateName();
    _validateEmail();
    _validatePassword();
    _validateConfirmPassword();
    if (mounted) setState(() {});
  }

  void _validateNickname() {
    final nickname = _nicknameController.text;
    if (nickname.isEmpty) {
      _isNicknameValid = true;
      _nicknameErrorMessage = '';
      return;
    }
    final byteLength = utf8.encode(nickname).length;
    if (byteLength < 6) {
      _isNicknameValid = false;
      _nicknameErrorMessage = '닉네임은 한글 2자, 영문 6자 이상이어야 합니다';
    } else {
      _isNicknameValid = true;
      _nicknameErrorMessage = '';
    }
  }

  void _validateName() {
    final name = _nameController.text;
    if (name.isEmpty) {
      _isNameValid = true;
      _nameErrorMessage = '';
      return;
    }
    final byteLength = utf8.encode(name).length;
    if (byteLength < 2) {
      _isNameValid = false;
      _nameErrorMessage = '이름은 2자 이상 입력해주세요';
    } else {
      _isNameValid = true;
      _nameErrorMessage = '';
    }
  }

  void _validateEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _isEmailValid = true;
      _emailErrorMessage = '';
      return;
    }
    final emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegExp.hasMatch(email)) {
      _isEmailValid = false;
      _emailErrorMessage = '올바른 이메일 형식이 아닙니다';
    } else {
      _isEmailValid = true;
      _emailErrorMessage = '';
    }
  }

  void _validatePassword() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      _isPasswordValid = false;
      _passwordErrorMessage = '';
      return;
    }
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    if (password.length < 8) {
      _isPasswordValid = false;
      _passwordErrorMessage = '비밀번호는 8자 이상이어야 합니다';
    } else if (!(hasLetter && hasDigit && hasSpecial)) {
      _isPasswordValid = false;
      _passwordErrorMessage = '영문, 숫자, 특수문자를 모두 포함해야 합니다';
    } else {
      _isPasswordValid = true;
      _passwordErrorMessage = '';
    }
  }

  void _validateConfirmPassword() {
    final confirmPassword = _confirmPasswordController.text;
    if (confirmPassword.isEmpty) {
      _confirmPasswordErrorMessage = '';
    } else if (!_isPasswordValid) {
      _confirmPasswordErrorMessage = '먼저 유효한 비밀번호를 입력해주세요';
    } else if (_passwordController.text != confirmPassword) {
      _confirmPasswordErrorMessage = '비밀번호가 일치하지 않습니다';
    } else {
      _confirmPasswordErrorMessage = '';
    }
  }

  bool _canSubmit(UserProvider userProvider) {
    final nicknameBytes = utf8.encode(_nicknameController.text).length;
    final isNicknameReady =
        _nicknameController.text.isNotEmpty &&
        nicknameBytes >= 6 &&
        userProvider.state == UserNickNameCheckState.available;

    return isNicknameReady &&
        _nameController.text.isNotEmpty &&
        _isNameValid &&
        _emailController.text.trim().isNotEmpty &&
        _isEmailValid &&
        _isPasswordValid &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text;
  }

  Future<void> _submitSignUp(UserProvider userProvider) async {
    FocusScope.of(context).unfocus();
    final success = await userProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      checkPassword: _confirmPasswordController.text,
      userNickName: _nicknameController.text,
      name: _nameController.text,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (success) {
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: Text('회원가입 성공! 닉네임: ${userProvider.currentUser?.displayName}'),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TermsGatePage()),
      );
    } else {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: Text('회원가입 실패! ${userProvider.errorMessage ?? '알 수 없는 오류'}'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final allFieldsReady = _canSubmit(userProvider);
    final canSubmit = allFieldsReady && !userProvider.isLoading;

    final confirmValid =
        _confirmPasswordController.text.isEmpty ||
        (_isPasswordValid &&
            _passwordController.text == _confirmPasswordController.text);

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  context.appLogoAsset,
                  height: 92,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '회원가입',
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
                '야구 일상을 시작할 계정을 만들어주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: GRAYSCALE_LABEL_600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 28),
              _buildInputField(
                label: '닉네임',
                hintText: '한글 2자 또는 영문 6자 이상',
                controller: _nicknameController,
                focusNode: _nicknameFocus,
                nextFocusNode: _nameFocus,
                prefixIcon: Icons.badge_outlined,
                isValid:
                    _isNicknameValid &&
                    userProvider.state != UserNickNameCheckState.duplicated,
                onChanged: (value) {
                  userProvider.onUserNickNameChanged(value);
                },
                statusWidget: _buildNicknameStatus(userProvider),
              ),
              const SizedBox(height: 16),
              _buildInputField(
                label: '이름',
                hintText: '이름을 입력해주세요',
                controller: _nameController,
                focusNode: _nameFocus,
                nextFocusNode: _emailFocus,
                prefixIcon: Icons.person_outline_rounded,
                isValid: _isNameValid,
                errorText: _nameErrorMessage,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                label: '이메일',
                hintText: 'example@email.com',
                controller: _emailController,
                focusNode: _emailFocus,
                nextFocusNode: _passwordFocus,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline_rounded,
                isValid: _isEmailValid,
                errorText: _emailErrorMessage,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                label: '비밀번호',
                hintText: '영문, 숫자, 특수문자 포함 8자 이상',
                controller: _passwordController,
                focusNode: _passwordFocus,
                nextFocusNode: _confirmPasswordFocus,
                isPassword: true,
                obscureText: _obscurePassword,
                onToggleObscure: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                prefixIcon: Icons.lock_outline_rounded,
                isValid: _passwordController.text.isEmpty || _isPasswordValid,
                errorText: _passwordErrorMessage,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                label: '비밀번호 확인',
                hintText: '비밀번호를 한 번 더 입력해주세요',
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocus,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (canSubmit) _submitSignUp(userProvider);
                },
                isPassword: true,
                obscureText: _obscureConfirmPassword,
                onToggleObscure: () {
                  setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
                prefixIcon: Icons.verified_user_outlined,
                isValid: confirmValid,
                errorText: _confirmPasswordErrorMessage,
              ),
              const SizedBox(height: 28),
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
                    onTap: canSubmit ? () => _submitSignUp(userProvider) : null,
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: Center(
                        child: userProvider.isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                '회원가입',
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
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '이미 계정이 있으신가요?',
                    style: TextStyle(color: GRAYSCALE_LABEL_600, fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('signIn');
                    },
                    style: TextButton.styleFrom(
                      overlayColor: Colors.transparent,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.only(left: 4.0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '로그인',
                      style: TextStyle(
                        color: BUTTON,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData prefixIcon,
    FocusNode? nextFocusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onFieldSubmitted,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    bool isValid = true,
    String? errorText,
    Widget? statusWidget,
  }) {
    final hasError =
        !isValid && !focusNode.hasFocus && controller.text.isNotEmpty;
    final showErrorText =
        errorText != null && errorText.isNotEmpty && controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: GRAYSCALE_LABEL_800,
            ),
          ),
        ),
        TextFormField(
          cursorColor: BUTTON,
          controller: controller,
          focusNode: focusNode,
          obscureText: isPassword ? obscureText : false,
          keyboardType: keyboardType,
          textInputAction:
              textInputAction ??
              (nextFocusNode != null
                  ? TextInputAction.next
                  : TextInputAction.done),
          onFieldSubmitted:
              onFieldSubmitted ??
              (_) {
                if (nextFocusNode != null) {
                  FocusScope.of(context).requestFocus(nextFocusNode);
                }
              },
          onChanged: onChanged,
          style: const TextStyle(fontSize: 15, color: GRAYSCALE_LABEL_950),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: GRAYSCALE_LABEL_400,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: WHITE,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            prefixIcon: Icon(prefixIcon, color: GRAYSCALE_LABEL_500, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: GRAYSCALE_LABEL_500,
                      size: 20,
                    ),
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: (hasError || showErrorText)
                    ? Colors.red.shade400
                    : GRAYSCALE_LABEL_200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: showErrorText ? Colors.red.shade400 : BUTTON,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (statusWidget != null) ...[
          const SizedBox(height: 6),
          Padding(padding: const EdgeInsets.only(left: 4), child: statusWidget),
        ] else if (showErrorText) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              errorText,
              style: TextStyle(
                color: Colors.red.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildNicknameStatus(UserProvider userProvider) {
    final nickname = _nicknameController.text;
    if (nickname.isEmpty) return null;

    final byteLength = utf8.encode(nickname).length;
    if (byteLength < 6) {
      return Text(
        '닉네임은 한글 2자, 영문 6자 이상이어야 합니다',
        style: TextStyle(
          color: Colors.red.shade500,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    switch (userProvider.state) {
      case UserNickNameCheckState.idle:
        return const Text(
          '닉네임을 확인 중입니다...',
          style: TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 12),
        );
      case UserNickNameCheckState.checking:
        return Row(
          children: [
            SizedBox(
              height: 13,
              width: 13,
              child: CircularProgressIndicator(strokeWidth: 2, color: BUTTON),
            ),
            const SizedBox(width: 6),
            const Text(
              '중복 확인 중...',
              style: TextStyle(color: GRAYSCALE_LABEL_600, fontSize: 12),
            ),
          ],
        );
      case UserNickNameCheckState.available:
        return Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: GREEN_SUCCESS_TEXT_50,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              userProvider.message ?? '사용 가능한 닉네임입니다.',
              style: const TextStyle(
                color: GREEN_SUCCESS_TEXT_50,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case UserNickNameCheckState.duplicated:
        return Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade500,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              userProvider.message ?? '이미 사용 중인 닉네임입니다.',
              style: TextStyle(
                color: Colors.red.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      case UserNickNameCheckState.error:
        return Text(
          userProvider.message ?? '확인 중 오류가 발생했습니다.',
          style: const TextStyle(color: Colors.orange, fontSize: 12),
        );
    }
  }
}
