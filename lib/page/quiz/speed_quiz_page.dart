import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/multiplayer_game_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/provider/badge_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';

class SpeedQuizPage extends StatefulWidget {
  const SpeedQuizPage({super.key});

  @override
  State<SpeedQuizPage> createState() => _SpeedQuizPageState();
}

class _SpeedQuizPageState extends State<SpeedQuizPage> {
  String? _feedbackText;
  bool? _isFeedbackSuccess;
  Timer? _feedbackTimer;
  int? _lastRoundNumber;
  int _elapsedSeconds = 0;
  bool _hasCheckedBadges = false;

  String _getConsonants(String text) {
    const double baseCode = 44032;
    const double initialSoundCode = 588;
    const List<String> initialSounds = [
      'ㄱ',
      'ㄲ',
      'ㄴ',
      'ㄷ',
      'ㄸ',
      'ㄹ',
      'ㅁ',
      'ㅂ',
      'ㅃ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅉ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ',
    ];

    String result = '';
    for (int i = 0; i < text.length; i++) {
      if (text[i] == ' ') {
        result += ' ';
        continue;
      }
      int code = text.codeUnitAt(i);
      if (code >= 44032 && code <= 55203) {
        int index = ((code - baseCode) / initialSoundCode).floor();
        result += initialSounds[index];
      } else {
        result += text[i];
      }
    }
    return result;
  }

  Future<void> _shareViaKakao(String roomCode) async {
    try {
      final template = FeedTemplate(
        content: Content(
          title: '[LockerRoom] 스피드 퀴즈 초대! 🎤',
          description: '방 코드: $roomCode\n지금 바로 접속해서 함께 퀴즈를 풀어보세요!',
          imageUrl: Uri.parse(
            'https://github.com/Deokwon-Kim/LockerRoom/blob/dev/ios/Runner/Assets.xcassets/AppIcon.appiconset/256.png?raw=true',
          ),
          link: Link(
            webUrl: Uri.parse('https://lockerroom-e9f39.web.app/'),
            mobileWebUrl: Uri.parse('https://lockerroom-e9f39.web.app/'),
          ),
        ),
        buttons: [
          Button(
            title: '퀴즈 참여하기',
            link: Link(
              webUrl: Uri.parse('https://lockerroom-e9f39.web.app/'),
              mobileWebUrl: Uri.parse('https://lockerroom-e9f39.web.app/'),
            ),
          ),
        ],
      );

      bool isKakaoTalkSharingAvailable = await ShareClient.instance
          .isKakaoTalkSharingAvailable();

      if (isKakaoTalkSharingAvailable) {
        Uri uri = await ShareClient.instance.shareDefault(template: template);
        await ShareClient.instance.launchKakaoTalk(uri);
      } else {
        Uri shareUrl = await WebSharerClient.instance.makeDefaultUrl(
          template: template,
        );
        await launchBrowserTab(shareUrl);
      }
    } catch (e) {
      debugPrint('Kakao sharing error: $e');
    }
  }

  void _shareViaGeneral(String roomCode) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    Share.share(
      '[LockerRoom] 스피드 퀴즈 방에 초대합니다! 🎤\n방 코드: $roomCode\n\n지금 바로 접속해서 함께 퀴즈를 풀어보세요!',
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
  }

  void _showShareOptions(BuildContext context, String roomCode) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: BACKGROUND_COLOR,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Image.asset('assets/images/logo/kakao.png', height: 24),
              title: const Text('카카오톡으로 공유'),
              onTap: () {
                Navigator.pop(context);
                _shareViaKakao(roomCode);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('기타 SNS로 공유'),
              onTap: () {
                Navigator.pop(context);
                _shareViaGeneral(roomCode);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedback(String text, bool isSuccess) {
    if (!mounted) return;
    setState(() {
      _feedbackText = text;
      _isFeedbackSuccess = isSuccess;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _feedbackText = null;
          _isFeedbackSuccess = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<MultiplayerGameProvider>();
    final roomData = gameProvider.roomData;
    final teamProvider = context.read<TeamProvider>();
    final teamColor = teamProvider.selectedTeam?.color;

    if (roomData == null) {
      return const Scaffold(
        backgroundColor: BACKGROUND_COLOR,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final players = List.from(roomData['players'] ?? []);
    final status = roomData['status'];

    // 게임 상태가 'waiting'으로 돌아오면(다시하기 선택 시) 로컬 상태 초기화
    if (status == 'waiting') {
      _hasCheckedBadges = false;
      _lastRoundNumber = null;
      _elapsedSeconds = 0;
    }

    // 라운드 진행 감지 (정답 처리 시 모든 참여자에게 피드백)
    final currentRound = roomData['currentRound'];
    if (currentRound != null) {
      final roundNumber = currentRound['roundNumber'] as int;
      final lastResult = currentRound['lastResult'] as String?;

      if (_lastRoundNumber != null &&
          _lastRoundNumber! > 0 &&
          roundNumber > _lastRoundNumber!) {
        // 라운드가 넘어갔다는 것은 누군가 정답을 맞췄거나 시간 초과되었다는 의미
        _elapsedSeconds = 0; // 타이머 로컬 상태 초기화

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (lastResult == 'timeout') {
            _showFeedback('시간초과! ⏰', false);
          } else {
            _showFeedback('정답입니다! 👏', true);
          }
        });
      }
      _lastRoundNumber = roundNumber;
    }

    // 게임 종료 시 뱃지 체크
    if (status == 'finished' && !_hasCheckedBadges) {
      _hasCheckedBadges = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<BadgeProvider>().checkSpeedQuizBadges(players).then((
          newBadges,
        ) {
          if (newBadges.isNotEmpty && mounted) {
            _showFeedback('${newBadges.join(", ")} 뱃지 획득! 🎉', true);
          }
        });
      });
    }

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          '방 코드: ${gameProvider.currentRoomId}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'kbo',
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ConfirmationDialog(
                  title: '나가기',
                  content: '정말 방을 나가시겠습니까?',
                  confirmText: '나가기',
                  confirmColor: Colors.red,
                  onConfirm: () {
                    gameProvider.leaveRoom();
                    Navigator.pop(context); // 다이얼로그 닫기
                    Navigator.pop(context); // 페이지 닫기
                  },
                ),
              );
            },
            icon: const Icon(Icons.exit_to_app, color: Colors.red),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 참여자 목록 (가로 스크롤)
          Container(
            height: 160,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: players.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final p = players[index];
                final isMe = p['uid'] == FirebaseAuth.instance.currentUser?.uid;
                return Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: isMe
                            ? Border.all(
                                color: teamColor ?? ORANGE_PRIMARY_500,
                                width: 3,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p['nickname'][0],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p['nickname'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                        color: isMe ? Colors.black : GRAYSCALE_LABEL_700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: GRAYSCALE_LABEL_100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${p['score']}점',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: GRAYSCALE_LABEL_600,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1, color: GRAYSCALE_LABEL_200),

          // 2. 메인 게임 영역
          Expanded(
            child: _buildMainBody(context, gameProvider, players, status),
          ),
        ],
      ),
      // 3. 하단 마이크 컨트롤
      bottomNavigationBar: status == 'finished'
          ? null
          : Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton.extended(
                      onPressed: () => gameProvider.toggleMic(),
                      backgroundColor: gameProvider.isMicOn
                          ? const Color(0xFF4CAF50) // Green
                          : GRAYSCALE_LABEL_400, // Gray
                      icon: Icon(
                        gameProvider.isMicOn ? Icons.mic : Icons.mic_off,
                        color: Colors.white,
                      ),
                      label: Text(
                        gameProvider.isMicOn ? '마이크 켜짐' : '마이크 꺼짐',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      elevation: 2,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMainBody(
    BuildContext context,
    MultiplayerGameProvider gameProvider,
    List players,
    String? status,
  ) {
    if (status == 'waiting') {
      return _buildWaitingView(context, gameProvider, players);
    } else if (status == 'playing') {
      return _buildGameView(context, gameProvider, players);
    } else if (status == 'finished') {
      return _buildFinishedView(context, gameProvider, players);
    } else {
      return const Center(child: Text("알 수 없는 상태입니다."));
    }
  }

  // 대기 화면
  Widget _buildWaitingView(
    BuildContext context,
    MultiplayerGameProvider gameProvider,
    List players,
  ) {
    final isHost =
        players.isNotEmpty &&
        players[0]['uid'] == FirebaseAuth.instance.currentUser?.uid;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sports_baseball,
              size: 80,
              color: GRAYSCALE_LABEL_300,
            ),
            const SizedBox(height: 24),
            const Text(
              '플레이어를 기다리고 있습니다...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: GRAYSCALE_LABEL_600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '현재 ${players.length}명 참여 중',
              style: const TextStyle(fontSize: 16, color: GRAYSCALE_LABEL_500),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                final roomCode = gameProvider.currentRoomId;
                if (roomCode != null) {
                  _showShareOptions(context, roomCode);
                }
              },
              icon: const Icon(Icons.share, size: 20),
              label: const Text('방 코드 공유하기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: GRAYSCALE_LABEL_600,
                side: const BorderSide(color: GRAYSCALE_LABEL_300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 48),

            if (isHost)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    gameProvider.startGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        context.read<TeamProvider>().selectedTeam?.color ??
                        ORANGE_PRIMARY_500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '게임 시작',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            if (!isHost)
              const Text(
                '방장이 게임을 시작할 때까지\n잠시만 기다려주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: GRAYSCALE_LABEL_500, height: 1.5),
              ),
          ],
        ),
      ),
    );
  }

  // 게임 진행 화면
  Widget _buildGameView(
    BuildContext context,
    MultiplayerGameProvider provider,
    List players,
  ) {
    final round = provider.roomData?['currentRound'];
    if (round == null) return const Center(child: Text("라운드 준비 중..."));

    final roundNumber = round['roundNumber'];
    final describerId = round['describerId'];
    final targetWord = round['targetWord'];
    final startTime = round['startTime'] as Timestamp?;
    final isDescriber = describerId == FirebaseAuth.instance.currentUser?.uid;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: GRAYSCALE_LABEL_100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ROUND $roundNumber',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: GRAYSCALE_LABEL_600,
                    ),
                  ),
                ),
                if (startTime != null)
                  _TimerWidget(
                    key: Key(startTime.toString()),
                    startTime: startTime,
                    onTick: (elapsed) {
                      if (_elapsedSeconds != elapsed) {
                        setState(() {
                          _elapsedSeconds = elapsed;
                        });
                      }
                    },
                    onTimeout: () {
                      final isHost =
                          players.isNotEmpty &&
                          players[0]['uid'] ==
                              FirebaseAuth.instance.currentUser?.uid;
                      if (isHost) {
                        provider.skipRound();
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 40),

            // 피드백 오버레이 또는 일반 게임 콘텐츠
            if (_feedbackText != null)
              _buildFeedbackView()
            else if (isDescriber) ...[
              const Text(
                '당신은 출제자입니다! 🎤',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ORANGE_PRIMARY_500,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '아래 단어를 설명해주세요',
                style: TextStyle(fontSize: 16, color: GRAYSCALE_LABEL_600),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      targetWord,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'kbo',
                        color: Colors.black,
                      ),
                    ),
                    if (_elapsedSeconds >= 30) ...[
                      const SizedBox(height: 12),
                      Text(
                        '힌트 공개 중: ${_getConsonants(targetWord)}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: ORANGE_PRIMARY_500,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else if (_elapsedSeconds >= 25) ...[
                      const SizedBox(height: 12),
                      Text(
                        '잠시 후 힌트가 공개됩니다! (${30 - _elapsedSeconds})',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              const Text(
                '설명을 듣고 정답을 맞춰보세요!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (_elapsedSeconds >= 30) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ORANGE_PRIMARY_500.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ORANGE_PRIMARY_500),
                  ),
                  child: Text(
                    '초성 힌트: ${_getConsonants(targetWord)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ORANGE_PRIMARY_500,
                    ),
                  ),
                ),
              ] else if (_elapsedSeconds >= 25) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Text(
                    '잠시 후 힌트가 공개됩니다! (${30 - _elapsedSeconds})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              _AnswerInputWidget(provider: provider, onResult: _showFeedback),
            ],
          ],
        ),
      ),
    );
  }

  // 정답/오답 피드백 화면
  Widget _buildFeedbackView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _isFeedbackSuccess!
                ? Icons.check_circle_outline
                : Icons.cancel_outlined,
            size: 80,
            color: _isFeedbackSuccess! ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            _feedbackText!,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _isFeedbackSuccess! ? Colors.green : Colors.red,
              fontFamily: 'kbo',
            ),
          ),
        ],
      ),
    );
  }

  // 결과 화면
  Widget _buildFinishedView(
    BuildContext context,
    MultiplayerGameProvider gameProvider,
    List players,
  ) {
    final sortedPlayers = List.from(players);
    sortedPlayers.sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0));

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Text(
          "게임 종료! 🏁",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'kbo',
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: Column(
            children: [
              // 최고의 설명왕 (MVP) 발표
              if (sortedPlayers.isNotEmpty)
                Builder(
                  builder: (context) {
                    final mvp = players.reduce(
                      (curr, next) =>
                          (curr['describerScore'] ?? 0) >
                              (next['describerScore'] ?? 0)
                          ? curr
                          : next,
                    );
                    if ((mvp['describerScore'] ?? 0) == 0)
                      return const SizedBox();

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.stars,
                            color: Colors.white,
                            size: 40,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '최고의 설명왕 (MVP)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${mvp['nickname']}님',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'kbo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${mvp['describerScore']}회',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  itemCount: sortedPlayers.length,
                  itemBuilder: (context, index) {
                    final p = sortedPlayers[index];
                    final isMe =
                        p['uid'] == FirebaseAuth.instance.currentUser?.uid;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isMe
                            ? ORANGE_PRIMARY_500.withOpacity(0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: isMe
                            ? Border.all(color: ORANGE_PRIMARY_500, width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(
                            "${index + 1}위",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            p['nickname'],
                            style: const TextStyle(fontSize: 18),
                          ),
                          const Spacer(),
                          Text(
                            "${p['score']}점",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isMe ? ORANGE_PRIMARY_500 : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              if (players.isNotEmpty &&
                  players[0]['uid'] ==
                      FirebaseAuth.instance.currentUser?.uid) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => gameProvider.restartGame(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "다시하기",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    gameProvider.leaveRoom();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "로비로 돌아가기",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 타이머 위젯
class _TimerWidget extends StatefulWidget {
  final Timestamp startTime;
  final Function(int)? onTick;
  final VoidCallback? onTimeout;
  const _TimerWidget({
    super.key,
    required this.startTime,
    this.onTick,
    this.onTimeout,
  });

  @override
  State<_TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<_TimerWidget> {
  int _remainingSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateRemaining();
        });
      }
    });
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    final start = widget.startTime.toDate();
    final elapsed = now.difference(start).inSeconds;
    final newRemaining = 60 - elapsed;

    if (newRemaining != _remainingSeconds) {
      if (newRemaining <= 10 && newRemaining > 0) {
        // 10초 이하일 때 매초 소리와 진동 발생
        HapticFeedback.selectionClick();
        SystemSound.play(SystemSoundType.click);
      }
      _remainingSeconds = newRemaining;
      widget.onTick?.call(elapsed);
    }

    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
      _timer?.cancel();
      widget.onTimeout?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _remainingSeconds <= 10
            ? Colors.red.withOpacity(0.1)
            : GRAYSCALE_LABEL_100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 16,
            color: _remainingSeconds <= 10 ? Colors.red : GRAYSCALE_LABEL_600,
          ),
          const SizedBox(width: 4),
          Text(
            '$_remainingSeconds초',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _remainingSeconds <= 10 ? Colors.red : GRAYSCALE_LABEL_600,
            ),
          ),
        ],
      ),
    );
  }
}

// 정답 입력 위젯
class _AnswerInputWidget extends StatefulWidget {
  final MultiplayerGameProvider provider;
  final Function(String, bool) onResult;

  const _AnswerInputWidget({required this.provider, required this.onResult});

  @override
  State<_AnswerInputWidget> createState() => _AnswerInputWidgetState();
}

class _AnswerInputWidgetState extends State<_AnswerInputWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _isError = false;

  void _handleResult(bool success) {
    if (!mounted) return;

    setState(() {
      _isError = !success;
    });

    if (success) {
      widget.onResult('정답입니다!', true);
      _controller.clear();
    } else {
      widget.onResult('오답입니다!', false);
      // 1초 후 에러 상태 해제
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isError = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: '정답 입력',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _isError ? Colors.red : ORANGE_PRIMARY_500,
                width: 2,
              ),
            ),
          ),
          style: TextStyle(
            fontSize: 18,
            color: _isError ? Colors.red : Colors.black,
            fontWeight: _isError ? FontWeight.bold : FontWeight.normal,
          ),
          onSubmitted: (value) async {
            if (value.trim().isEmpty) return;
            final success = await widget.provider.submitAnswer(value);
            _handleResult(success);
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final value = _controller.text.trim();
              if (value.isEmpty) return;
              final success = await widget.provider.submitAnswer(value);
              _handleResult(success);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ORANGE_PRIMARY_500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              '제출',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
