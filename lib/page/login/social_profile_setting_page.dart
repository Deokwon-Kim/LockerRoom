import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/login/terms_gate_page.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';

class SocialProfileSettingPage extends StatefulWidget {
  const SocialProfileSettingPage({super.key});

  @override
  State<SocialProfileSettingPage> createState() =>
      _SocialProfileSettingPageState();
}

class _SocialProfileSettingPageState extends State<SocialProfileSettingPage> {
  final TextEditingController _nickNameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nickNameFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();

  bool _isNicknameValid = true;
  bool _isNameValid = true;
  bool _isAppleLogin = false;
  bool _isSubmitting = false;
  String _nameErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkLoginProvider();
    _nickNameController.addListener(_onFormChanged);
    _nameController.addListener(_onFormChanged);
    _nickNameFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _nameFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nickNameController.dispose();
    _nameController.dispose();
    _nickNameFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _checkLoginProvider() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isApple = user.providerData.any(
      (element) => element.providerId == 'apple.com',
    );
    _isAppleLogin = isApple;

    if (isApple && user.displayName != null && user.displayName!.isNotEmpty) {
      final parts = user.displayName!.trim().split(' ');
      final koreanName = parts.length >= 2
          ? parts.reversed.join('')
          : user.displayName!.replaceAll(' ', '');
      _nameController.text = koreanName;
    }
  }

  void _onFormChanged() {
    final nickname = _nickNameController.text;
    _isNicknameValid = nickname.isEmpty || utf8.encode(nickname).length >= 6;

    final name = _nameController.text;
    if (name.isEmpty) {
      _isNameValid = true;
      _nameErrorMessage = '';
    } else if (utf8.encode(name).length < 2) {
      _isNameValid = false;
      _nameErrorMessage = '이름은 2자 이상 입력해주세요';
    } else {
      _isNameValid = true;
      _nameErrorMessage = '';
    }

    if (mounted) setState(() {});
  }

  bool _canSubmit(UserProvider userProvider) {
    final nickname = _nickNameController.text;
    final isNicknameReady =
        nickname.isNotEmpty &&
        utf8.encode(nickname).length >= 6 &&
        userProvider.state == UserNickNameCheckState.available;

    return isNicknameReady &&
        (_isAppleLogin || (_nameController.text.isNotEmpty && _isNameValid));
  }

  Future<void> _submitProfile() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid);
      final nameToSave = _isAppleLogin
          ? (currentUser.displayName ?? '')
          : _nameController.text.trim();

      await userDoc.set({
        'userNickName': _nickNameController.text,
        'name': nameToSave,
        'isProfileCompleted': true,
      }, SetOptions(merge: true));

      if (!mounted) return;
      await context.read<UserProvider>().loadNickname();
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const TermsGatePage()),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final canSubmit = _canSubmit(userProvider) && !_isSubmitting;

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          '프로필 설정',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: GRAYSCALE_LABEL_950,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        '당신의 팬 프로필을 완성해주세요',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: GRAYSCALE_LABEL_950,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '커뮤니티에서 사용할 닉네임을 설정해주세요',
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
                        controller: _nickNameController,
                        focusNode: _nickNameFocus,
                        nextFocusNode: _isAppleLogin ? null : _nameFocus,
                        prefixIcon: Icons.badge_outlined,
                        isValid:
                            _isNicknameValid &&
                            userProvider.state !=
                                UserNickNameCheckState.duplicated,
                        onChanged: (value) {
                          context.read<UserProvider>().onUserNickNameChanged(
                            value,
                          );
                        },
                        statusWidget: _buildNicknameStatus(userProvider),
                      ),
                      if (!_isAppleLogin) ...[
                        const SizedBox(height: 18),
                        _buildInputField(
                          label: '이름',
                          hintText: '이름을 입력해주세요',
                          controller: _nameController,
                          focusNode: _nameFocus,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (canSubmit) _submitProfile();
                          },
                          prefixIcon: Icons.person_outline_rounded,
                          isValid: _isNameValid,
                          errorText: _nameErrorMessage,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                child: Container(
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
                      onTap: canSubmit ? _submitProfile : null,
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: Center(
                          child: (_isSubmitting || userProvider.isLoading)
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: WHITE,
                                  ),
                                )
                              : const Text(
                                  '다음',
                                  style: TextStyle(
                                    color: WHITE,
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
              ),
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
    bool isValid = true,
    String? errorText,
    Widget? statusWidget,
  }) {
    final hasError =
        !isValid && !focusNode.hasFocus && controller.text.isNotEmpty;
    final showErrorText =
        errorText != null &&
        errorText.isNotEmpty &&
        controller.text.isNotEmpty;

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
          style: const TextStyle(
            fontSize: 15,
            color: GRAYSCALE_LABEL_950,
          ),
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
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: statusWidget,
          ),
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
    final nickname = _nickNameController.text;
    if (nickname.isEmpty) return null;

    if (utf8.encode(nickname).length < 6) {
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
