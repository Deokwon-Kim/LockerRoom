import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class NicknameChangePage extends StatefulWidget {
  const NicknameChangePage({super.key});

  @override
  State<NicknameChangePage> createState() => _NicknameChangePageState();
}

class _NicknameChangePageState extends State<NicknameChangePage> {
  final TextEditingController _nickNameController = TextEditingController();
  String _enteredNickname = "";
  bool _isNicknameChangeConfirmed = false;
  String _currentNicknameHint = "현재 닉네임: ";
  String? _currentNickname;
  String initialNickname = '';
  String validationLabelString = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentNickname();
  }

  @override
  void dispose() {
    _nickNameController.dispose();
    super.dispose();
  }

  void _onNicknameChanged(String value) {
    if (mounted) {
      setState(() {
        _enteredNickname = value;
        if (value.length < 2 || value.length > 8) {
          validationLabelString = "닉네임은 2~8자여야 합니다.";
        } else {
          validationLabelString = '';
        }
      });
    }
  }

  Future<void> _showConfirmationDialog() async {
    if (_nickNameController.text.isEmpty) {
      return;
    }
    if (_nickNameController.text ==
            _currentNicknameHint.substring(
              _currentNicknameHint.indexOf(':') + 2,
            ) &&
        _currentNicknameHint.startsWith("현재 닉네임:")) {
      return;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          title: '닉네임 변경',
          content: "'${_nickNameController.text}' (으)로 변경하시겠습니까?",
          onConfirm: nicknameChange,
        );
      },
    );
  }

  void nicknameChange() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final newNickname = _nickNameController.text.trim();
      await context.read<UserProvider>().updateNickname(newNickname);
      await FirebaseAuth.instance.currentUser?.updateDisplayName(newNickname);
      if (!mounted) return;

      if (mounted) {
        setState(() {
          _isNicknameChangeConfirmed = true;
          _currentNicknameHint = "현재 닉네임: $_currentNickname";
          _enteredNickname = "";
          _isLoading = false;
        });
      }
      Navigator.pop(context);
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.flat,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        title: Text('닉네임이 변경되었습니다.'),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          title: Text('닉네임 변경 실패: ${e.toString()}'),
        );
      }
      // print("닉네임 변경 실패: $e");
    }
  }

  Future<void> _loadCurrentNickname() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final nickname = doc.data()?['userNickName'] ?? '닉네임 없음';

    if (mounted) {
      setState(() {
        _currentNickname = nickname;
        _currentNicknameHint = "현재 닉네임: $nickname";
      });
    }
    // print(nickname);
    initialNickname = nickname;
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = Provider.of<TeamProvider>(context, listen: false);
    final userProvider = context.watch<UserProvider>();
    const double fieldHeight = 52.0;
    const double horizontalPageMargin = 20.0;
    const double borderRadiusValue = 8.0;

    return Scaffold(
      backgroundColor: WHITE,
      appBar: AppBar(
        backgroundColor: WHITE,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: GRAYSCALE_LABEL_950),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          "닉네임 변경",
          style: TextStyle(
            color: GRAYSCALE_LABEL_950,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: horizontalPageMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(height: 40),
            Text(
              "변경하실 닉네임을 입력해주세요",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: GRAYSCALE_LABEL_900,
              ),
            ),
            SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: fieldHeight,
                    child: TextField(
                      controller: _nickNameController,
                      onChanged: (value) {
                        _onNicknameChanged(value);
                        context.read<UserProvider>().onUserNickNameChanged(
                          value,
                        );
                      },

                      cursorColor: teamProvider.selectedTeam!.color,
                      decoration: InputDecoration(
                        hintText: _currentNicknameHint,
                        hintStyle: TextStyle(
                          color: GRAYSCALE_LABEL_500,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: WHITE,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            borderRadiusValue,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            borderRadiusValue,
                          ),
                          borderSide: BorderSide(
                            color: GRAYSCALE_LABEL_400,
                            width: 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            borderRadiusValue,
                          ),
                          borderSide: BorderSide(
                            color: teamProvider.selectedTeam!.color,
                            width: 1.0,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: (fieldHeight - 20) / 2,
                        ),
                        counterText: '',
                      ),
                      maxLength: 8,
                      style: TextStyle(
                        fontSize: 14,
                        color: GRAYSCALE_LABEL_950,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                if (!_isNicknameChangeConfirmed)
                  SizedBox(
                    height: fieldHeight,
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: teamProvider.selectedTeam!.color,
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              if (_enteredNickname.isEmpty ||
                                  _nickNameController.text == initialNickname ||
                                  _enteredNickname.length < 2 ||
                                  _enteredNickname.length > 8 ||
                                  userProvider.state !=
                                      UserNickNameCheckState.available) {
                                ();
                              } else {
                                _showConfirmationDialog();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  (_enteredNickname.isEmpty ||
                                      _nickNameController.text ==
                                          initialNickname ||
                                      _enteredNickname.length < 2 ||
                                      _enteredNickname.length > 8 ||
                                      userProvider.state !=
                                          UserNickNameCheckState.available)
                                  ? GRAYSCALE_LABEL_300
                                  : teamProvider.selectedTeam!.color,
                              foregroundColor: WHITE,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  borderRadiusValue,
                                ),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              elevation: 0,
                            ),
                            child: Text(
                              "변경하기",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
            if (_enteredNickname.isNotEmpty &&
                _enteredNickname != initialNickname)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _buildNickNameCheckStatus(userProvider),
              ),
            if (_enteredNickname.isEmpty)
              if (_enteredNickname.isNotEmpty && !_isNicknameChangeConfirmed)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    "변경 전 닉네임: $initialNickname",
                    style: TextStyle(fontSize: 14, color: GRAYSCALE_LABEL_700),
                  ),
                ),
            if (validationLabelString.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  validationLabelString,
                  style: TextStyle(fontSize: 13, color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 중복검사 상태 펴시 위젯
  Widget _buildNickNameCheckStatus(UserProvider userProvider) {
    switch (userProvider.state) {
      case UserNickNameCheckState.idle:
      case UserNickNameCheckState.checking:
        return Row(
          children: [
            SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: GRAYSCALE_LABEL_700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '중복 확인 중...',
              style: TextStyle(fontSize: 13, color: GRAYSCALE_LABEL_700),
            ),
          ],
        );
      case UserNickNameCheckState.available:
        return Text(
          userProvider.message ?? '사용 가능한 닉네임 입니다.',
          style: TextStyle(fontSize: 13, color: Colors.green),
        );
      case UserNickNameCheckState.duplicated:
        return Text(
          userProvider.message ?? '이미 사용 중인 닉네임 입니다.',
          style: TextStyle(fontSize: 13, color: Colors.red),
        );
      case UserNickNameCheckState.error:
        return Text(
          userProvider.message ?? '확인 중 오류가 발생했습니다.',
          style: TextStyle(fontSize: 13, color: Colors.orange),
        );
    }
  }
}
