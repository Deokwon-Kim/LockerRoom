import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/page/quiz/speed_quiz_page.dart';
import 'package:lockerroom/provider/multiplayer_game_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class SpeedQuizLoby extends StatefulWidget {
  final UserModel? userModel;
  const SpeedQuizLoby({super.key, this.userModel});

  @override
  State<SpeedQuizLoby> createState() => _SpeedQuizLobyState();
}

class _SpeedQuizLobyState extends State<SpeedQuizLoby> {
  final TextEditingController _codeController = TextEditingController();
  String _selectedTheme = '야구 용어';

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<MultiplayerGameProvider>();
    final teamProvider = context.read<TeamProvider>();
    final teamColor =
        teamProvider.selectedTeam?.color ?? const Color(0xFFE040FB);

    // 이미 방에 들어가 있을 경우 게임 화면으로 이동
    if (gameProvider.currentRoomId != null && gameProvider.roomData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SpeedQuizPage()),
        );
      });
    }

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '스피드 퀴즈',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'kbo',
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 40.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '친구와 함께하는\n스피드 퀴즈! 🎤',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kbo',
                    height: 1.3,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '공유받은 방 코드를 입력하거나\n새로운 방을 만들어보세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: GRAYSCALE_LABEL_600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),

                // 방 코드 입력 필드
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    cursorColor: teamColor,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: teamColor,
                    ),
                    decoration: InputDecoration(
                      counterText: "",
                      hintText: 'CODE',
                      hintStyle: const TextStyle(
                        color: GRAYSCALE_LABEL_300,
                        fontSize: 32,
                        letterSpacing: 2,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 24),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () async {
                    if (_codeController.text.length != 4) {
                      toastification.show(
                        context: context,
                        type: ToastificationType.warning,
                        title: const Text('방 코드 4자리를 입력해주세요.'),
                        autoCloseDuration: const Duration(seconds: 2),
                      );
                      return;
                    }

                    final success = await gameProvider.joinRoom(
                      _codeController.text,
                      widget.userModel?.userNickName ?? 'Guest',
                    );

                    if (!success && context.mounted) {
                      toastification.show(
                        context: context,
                        type: ToastificationType.error,
                        title: const Text('입장 실패'),
                        description: const Text('코드를 확인하거나 방이 꽉 찼는지 확인해주세요.'),
                        autoCloseDuration: const Duration(seconds: 3),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: teamColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '입장하기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 40),

                Row(
                  children: const [
                    Expanded(child: Divider(color: GRAYSCALE_LABEL_200)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: GRAYSCALE_LABEL_400,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: GRAYSCALE_LABEL_200)),
                  ],
                ),
                const SizedBox(height: 32),

                // 테마 선택
                const Text(
                  '퀴즈 테마 선택',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kbo',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['야구 용어', 'KBO 선수', '야구장 먹거리'].map((theme) {
                    final isSelected = _selectedTheme == theme;
                    return ChoiceChip(
                      label: Text(
                        theme,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: teamColor,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? teamColor : GRAYSCALE_LABEL_300,
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedTheme = theme;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                OutlinedButton.icon(
                  onPressed: () async {
                    await gameProvider.createRoom(
                      widget.userModel?.userNickName ?? 'Host',
                      theme: _selectedTheme,
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('새로운 방 만들기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: teamColor,
                    side: BorderSide(color: teamColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
