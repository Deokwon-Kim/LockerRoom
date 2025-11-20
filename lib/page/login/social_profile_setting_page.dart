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

  bool _allFieldsFilled = false;
  bool _isNicknameValid = true;
  bool _isNameValid = true;
  String _nickNameErrorMessage = '';
  String _nameErrorMessage = '';
  // 현재 포커스된 필드 추적
  String _currentFocusField = '';

  // 닉네임 유효성 검사
  void _validateNickname() {
    final nickname = _nickNameController.text;

    if (nickname.isEmpty) {
      _isNicknameValid = true;
      _nickNameErrorMessage = '';
      return;
    }

    // UTF-8 인코딩을 사용하여 바이트 수 계산
    final bytes = utf8.encode(nickname);
    final byteLength = bytes.length;

    setState(() {
      if (byteLength < 6) {
        _isNicknameValid = false;
        _nickNameErrorMessage = '닉네임은 한글 2자, 영문 6자 이상이어야 합니다';
      } else {
        _isNicknameValid = true;
        _nickNameErrorMessage = '';
      }
    });
  }

  // 이름 유효성 검사
  void _validateName() {
    final name = _nameController.text;

    if (name.isEmpty) {
      _isNameValid = true;
      _nameErrorMessage = '';
      return;
    }

    // UTF-8 인코딩을 사용하여 바이트 수 계산
    final bytes = utf8.encode(name);
    final byteLength = bytes.length;

    setState(() {
      if (byteLength < 2) {
        _isNameValid = false;
        _nameErrorMessage = '이름은 2자 이상 10자 이하로 입력해주세요';
      } else {
        _isNameValid = true;
        _nameErrorMessage = '';
      }
    });
  }

  // 현재 표시할 에러 메시지 가져오기
  String _getCurrentErrorMessage() {
    // 모든 필드가 채워지고 유효하면 빈 메시지 반환
    if (_allFieldsFilled) {
      return '';
    }

    // 필드 입력 여부 확인
    bool hasEmptyField =
        _nickNameController.text.isEmpty || _nameController.text.isEmpty;

    // 닉네임 필드에 텍스트가 있고 유효하지 않은 경우
    if (_nickNameController.text.isNotEmpty && !_isNicknameValid) {
      return _nickNameErrorMessage;
    }

    // 이름 필드에 텍스트가 있고 유효하지 않은 경우
    if (_nameController.text.isNotEmpty && !_isNameValid) {
      return _nameErrorMessage;
    }

    // 현재 포커스된 필드의 에러 메시지 반환 (위의 조건에 해당하지 않는 경우)
    String errorMessage = '';
    switch (_currentFocusField) {
      case 'nickname':
        errorMessage = _nickNameErrorMessage.isNotEmpty
            ? _nickNameErrorMessage
            : '';
        break;
      case 'name':
        errorMessage = _nameErrorMessage.isNotEmpty ? _nameErrorMessage : '';
        break;
    }

    if (errorMessage.isNotEmpty) {
      return errorMessage;
    }

    // 다른 에러 메시지가 없고 입력란이 비어있으면 기본 메시지 반환
    if (hasEmptyField) {
      return '모든 입력란을 채워주세요';
    }

    return '';
  }

  void _checkFields() {
    final userProvider = context.read<UserProvider>();
    final nickname = _nickNameController.text;
    final bytes = utf8.encode(nickname);
    final byteLength = bytes.length;

    // 닉네임: 바이트 길이 6 이상 AND 중복 확인 완료(available 상태)
    bool isNicknameValid =
        nickname.isNotEmpty &&
        byteLength >= 6 &&
        userProvider.state == UserNickNameCheckState.available;

    setState(() {
      _allFieldsFilled =
          isNicknameValid && _nameController.text.isNotEmpty && _isNameValid;
    });
  }

  @override
  void dispose() {
    _nickNameController.dispose();
    _nameController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 중앙에 표시할 메시지 가져오기
    final String centerMessage = _getCurrentErrorMessage();
    final userProvider = context.watch<UserProvider>();

    // UserProvider 상태 변경 감시 후 필드 상태 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFields();
    });

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          '프로필 설정',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '당신의 팬 프로필을 완성해주세요',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _buildNickNameTextField(
              userProvider,
              '닉네임',
              _nickNameController,

              isValid: _isNicknameValid,
            ),
            const SizedBox(height: 20.0),
            _buildTextField('이름', _nameController, isValid: _isNameValid),
            const SizedBox(height: 20.0),
            Center(
              child: Text(
                centerMessage,
                style: TextStyle(
                  color: centerMessage.isEmpty
                      ? Colors.transparent
                      : Colors.red[400],
                  fontSize: 14.0,
                ),
              ),
            ),
            Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: SizedBox(
                width: double.infinity,
                height: 58.0,
                child: Consumer<UserProvider>(
                  builder: (context, userProvider, child) {
                    return ElevatedButton(
                      onPressed: () async {
                        final currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser != null) {
                          final userDoc = FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUser.uid);
                          await userDoc.set({
                            'userNickName': _nickNameController.text,
                            'name': _nameController.text,
                            'isProfileCompleted': true,
                          }, SetOptions(merge: true));
                          if (!mounted) return;
                          await context.read<UserProvider>().loadNickname();
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => TermsGatePage(),
                            ),
                          );
                        }
                      },

                      style: ElevatedButton.styleFrom(
                        overlayColor: Colors.transparent,
                        backgroundColor: BUTTON,
                        disabledBackgroundColor: GRAYSCALE_LABEL_300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: userProvider.isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              '회원가입',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hintText,
    TextEditingController controller, {
    FocusNode? focusNode,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? errorText,
    double height = 50.0,
    bool isValid = true,
  }) {
    // 현재 필드가 포커스되었는지 확인
    bool isFieldFocused = focusNode != null && focusNode.hasFocus;

    // 유효하지 않고 포커스가 없는 경우에만 빨간색 테두리 표시
    bool shouldShowRedBorder =
        !isValid && !isFieldFocused && controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color:
                  shouldShowRedBorder ||
                      (errorText != null && errorText.isNotEmpty)
                  ? Colors.red.shade400
                  : GRAYSCALE_LABEL_400,
              width: 1.0,
            ),
          ),
          child: TextFormField(
            cursorColor: BUTTON,
            controller: controller,
            focusNode: focusNode,
            obscureText: isPassword,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 15.0),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15.0),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNickNameTextField(
    UserProvider userProvider,
    String hintText,
    TextEditingController controller, {
    FocusNode? focusNode,
    TextInputType? keyboardType,
    String? errorText,
    double height = 50.0,
    bool isValid = true,
  }) {
    // 현재 필드가 포커스되었는지 확인
    bool isFieldFocused = focusNode != null && focusNode.hasFocus;

    // 유효하지 않고 포커스가 없는 경우에만 빨간색 테두리 표시
    bool shouldShowRedBorder =
        !isValid && !isFieldFocused && controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color:
                  shouldShowRedBorder ||
                      (errorText != null && errorText.isNotEmpty)
                  ? Colors.red.shade400
                  : GRAYSCALE_LABEL_400,
              width: 1.0,
            ),
          ),
          child: TextFormField(
            cursorColor: BUTTON,
            controller: _nickNameController,
            focusNode: focusNode,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 15.0),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15.0),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
            ),
            onChanged: (value) {
              _validateNickname();
              context.read<UserProvider>().onUserNickNameChanged(value);
            },
          ),
        ),

        const SizedBox(height: 16),
        _buildStatus(userProvider),
      ],
    );
  }

  Widget _buildStatus(UserProvider userProvider) {
    final nickname = _nickNameController.text;
    final bytes = utf8.encode(nickname);
    final byteLength = bytes.length;

    // 닉네임이 비어있으면 안내 메시지
    if (nickname.isEmpty) {
      return const Text('닉네임을 입력해주세요');
    }

    // 바이트 길이가 부족하면 길이 오류 표시
    if (byteLength < 6) {
      return Text(
        '닉네임은 한글 2자, 영문 6자 이상이어야 합니다',
        style: TextStyle(color: Colors.red[400]),
      );
    }

    // 바이트 길이 충분 → 중복 확인 상태 표시
    switch (userProvider.state) {
      case UserNickNameCheckState.idle:
        return const Text('닉네임을 확인 중입니다...');
      case UserNickNameCheckState.checking:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: BUTTON),
            ),
            const SizedBox(width: 8),
            const Text('중복 확인 중...'),
          ],
        );
      case UserNickNameCheckState.available:
        return Text(
          userProvider.message ?? '사용 가능한 닉네임입니다.',
          style: const TextStyle(color: Colors.green),
        );
      case UserNickNameCheckState.duplicated:
        return Text(
          userProvider.message ?? '이미 사용 중인 닉네임입니다.',
          style: const TextStyle(color: Colors.red),
        );
      case UserNickNameCheckState.error:
        return Text(
          userProvider.message ?? '확인 중 오류가 발생했습니다.',
          style: const TextStyle(color: Colors.orange),
        );
    }
  }
}
