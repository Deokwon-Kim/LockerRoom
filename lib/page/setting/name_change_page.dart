import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class NameChangePage extends StatefulWidget {
  const NameChangePage({super.key});

  @override
  State<NameChangePage> createState() => _NameChangePageState();
}

class _NameChangePageState extends State<NameChangePage> {
  final TextEditingController _nameChangeController = TextEditingController();
  String _enteredName = '';
  bool _isNameChangeConfirmed = false;
  String _currentNameHint = '현재 이름:';
  String? _currentName;
  String initialName = '';
  String validationLabelString = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentName();
  }

  @override
  void dispose() {
    _nameChangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.read<TeamProvider>();
    final userProvider = context.watch<UserProvider>();
    const double fieldHeight = 52.0;
    const double horizontalPageMargin = 20.0;
    const double borderRadiusValue = 8.0;

    return Scaffold(
      backgroundColor: WHITE,
      appBar: AppBar(
        backgroundColor: WHITE,
        elevation: 0,
        title: Text(
          "이름 변경",
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
              "변경하실 이름을 입력해주세요",
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
                      controller: _nameChangeController,
                      onChanged: _onNameChanged,

                      cursorColor: teamProvider.selectedTeam?.color,

                      decoration: InputDecoration(
                        hintText: _currentNameHint,
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
                if (!_isNameChangeConfirmed)
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
                              if (_enteredName.isEmpty ||
                                  _nameChangeController.text == initialName ||
                                  _enteredName.length < 2 ||
                                  _enteredName.length > 8 ||
                                  userProvider.state !=
                                      UserNickNameCheckState.available) {
                                ();
                              } else {
                                _showConfirmationDialog();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  (_enteredName.isEmpty ||
                                      _nameChangeController.text ==
                                          initialName ||
                                      _enteredName.length < 2 ||
                                      _enteredName.length > 8 ||
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

            if (_enteredName.isEmpty)
              if (_enteredName.isNotEmpty && !_isNameChangeConfirmed)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    "변경 전 이름: $initialName",
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

  void _onNameChanged(String value) {
    if (mounted) {
      setState(() {
        _enteredName = value;
        if (value.length < 2 || value.length > 6) {
          validationLabelString = '이름은 2~6자여야 합니다.';
        } else {
          validationLabelString = '';
        }
      });
    }
  }

  Future<void> _showConfirmationDialog() async {
    if (_nameChangeController.text.isEmpty) {
      return;
    }
    if (_nameChangeController.text ==
            _currentNameHint.substring(_currentNameHint.indexOf(':') + 2) &&
        _currentNameHint.startsWith('현재 이름:')) {
      return;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          title: '이름 변경',
          content: "'${_nameChangeController.text}' (으)로 변경하시겠습니까?",
          onConfirm: nameChange,
        );
      },
    );
  }

  void nameChange() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final newName = _nameChangeController.text.trim();
      await context.read<UserProvider>().updateName(newName);
      if (!mounted) return;

      if (mounted) {
        setState(() {
          _isNameChangeConfirmed = true;
          _currentNameHint = '현재 이름: $_currentName';
          _enteredName = '';
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
        title: Text('이름이 변경되었습니다.'),
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
          title: Text('이름 변경 실패: ${e.toString()}'),
        );
      }
    }
  }

  Future<void> _loadCurrentName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final name = doc.data()?['name'] ?? '이름 없음';

    if (mounted) {
      setState(() {
        _currentName = name;
        _currentNameHint = '현재 이름: $name';
      });
    }
    initialName = name;
  }
}
