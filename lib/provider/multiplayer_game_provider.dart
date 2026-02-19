import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'package:flutter/services.dart';

class MultiplayerGameProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Agora관련
  RtcEngine? _engine;
  bool _isJoined = false;
  bool _isMicOn = true;

  // 게임 상태
  String? _currentRoomId;
  Map<String, dynamic>? _roomData;
  StreamSubscription<DocumentSnapshot>? _roomSubscription;

  // 게터
  String? get currentRoomId => _currentRoomId;
  Map<String, dynamic>? get roomData => _roomData;
  bool get isJoined => _isJoined;
  bool get isMicOn => _isMicOn;

  // 단어 팩 데이터
  static const Map<String, List<String>> _wordPacks = {
    'KBO 선수': [
      '이대호',
      '김광현',
      '양현종',
      '강백호',
      '노시환',
      '손아섭',
      '최정',
      '오지환',
      '구자욱',
      '김도영',
      '전준우',
      '류현진',
      '안치홍',
      '문동주',
      '박병호',
      '나성범',
      '박민우',
      '최형우',
      '양의지',
      '홍창기',
    ],
    '야구장 먹거리': [
      '크림새우',
      '치맥',
      '떡볶이',
      '회오리감자',
      '마라탕',
      '큐브스테이크',
      '열무국수',
      '츄러스',
      '타코야끼',
      '닭강정',
      '핫도그',
      '삼겹살 도시락',
      '불막창',
      '순대볶음',
      '슬러시',
      '어묵',
      '만두',
      '피자',
      '쫄면',
      '김밥',
    ],
    '야구 용어': [
      '동점 홈런',
      '병살타',
      '인필드 플라이',
      '견제사',
      '희생 플라이',
      '낫아웃',
      '스트라이크 낫아웃',
      '보크',
      '고의사구',
      '탈삼진',
      '완봉승',
      '완투승',
      '홀드',
      '세이브',
      '사이클링 히트',
      '그라운드 홈런',
      '벤치 클리어링',
      '헤드샷 퇴장',
      '비디오 판정',
      '사인 훔치기',
    ],
  };

  // 1. 방 생성
  Future<String?> createRoom(String nickname, {String theme = '야구 용어'}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // 4자리 랜덤 코드 생성
      String roomCode = (1000 + Random().nextInt(9000)).toString();

      // 방 데이터 초기화
      final roomRef = _firestore.collection('game_rooms').doc(roomCode);

      await roomRef.set({
        'hostId': user.uid,
        'status': 'waiting',
        'theme': theme, // 선택된 테마 저장
        'describerIndex': 0, // 현재 출제자 인덱스 (게임 전체 한 명 유지)
        'createdAt': FieldValue.serverTimestamp(),
        'players': [
          {
            'uid': user.uid,
            'nickname': nickname,
            'score': 0,
            'describerScore': 0, // MVP 선정을 위한 설명 점수
            'isReady': true,
            'isHost': true,
          },
        ],
        'currentRound': {
          'roundNumber': 0,
          'describerId': '',
          'targetWord': '',
          'targetType': 'text',
          'hintOpen': false,
          'lastResult': null, // 'success' 또는 'timeout'
        },
      });

      _subscribeToRoom(roomCode);
      await _initAgora(roomCode, user.uid);

      return roomCode;
    } catch (e) {
      debugPrint('방 생성 실패: $e');
      return null;
    }
  }

  // 방 입장
  Future<bool> joinRoom(String roomCode, String nickname) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final roomRef = _firestore.collection('game_rooms').doc(roomCode);
      final doc = await roomRef.get();

      if (!doc.exists) return false;

      final data = doc.data();
      if (data?['status'] != 'waiting') return false;

      List players = List.from(data?['players'] ?? []);
      if (players.length >= 4) return false; // 만원

      // 이미 있는지 확인
      final existingIndex = players.indexWhere((p) => p['uid'] == user.uid);
      if (existingIndex == -1) {
        players.add({
          'uid': user.uid,
          'nickname': nickname,
          'score': 0,
          'describerScore': 0, // MVP 선정을 위한 설명 점수
          'isReady': false,
          'isHost': false,
        });

        await roomRef.update({'players': players});
      }

      _subscribeToRoom(roomCode);
      await _initAgora(roomCode, user.uid);

      return true;
    } catch (e) {
      debugPrint('방 입장 실패: $e');
      return false;
    }
  }

  // 방 구독
  void _subscribeToRoom(String roomCode) {
    _currentRoomId = roomCode;
    _roomSubscription?.cancel();
    _roomSubscription = _firestore
        .collection('game_rooms')
        .doc(roomCode)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            _roomData = snapshot.data();
            notifyListeners();
          } else {
            leaveRoom(); // 방 삭제 됨
          }
        });
  }

  // Agora 초기화
  Future<void> _initAgora(String channelName, String uid) async {
    if (dotenv.env['AGORA_APP_ID'] == null) return;

    // 권한 요청
    await [Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      RtcEngineContext(
        appId: dotenv.env['AGORA_APP_ID'],
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    await _engine!.enableAudio();
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          _isJoined = true;
          notifyListeners();
        },
      ),
    );

    // uid를 int로 변환
    int agoraUid = uid.hashCode.abs();
    await _engine!.joinChannel(
      token: "",
      channelId: channelName,
      uid: agoraUid,
      options: ChannelMediaOptions(),
    );
  }

  // 방 나가기
  Future<void> leaveRoom() async {
    _roomSubscription?.cancel();
    _roomSubscription = null;

    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
    }

    _isJoined = false;
    _currentRoomId = null;
    _roomData = null;
    notifyListeners();
  }

  // 마이크 토글
  Future<void> toggleMic() async {
    _isMicOn = !_isMicOn;

    // 효과음 및 진동 추가
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);

    if (_engine != null) {
      await _engine!.muteLocalAudioStream(!_isMicOn);
    }
    notifyListeners();
  }

  // 게임 시작 (방장만 호출 가능)
  Future<void> startGame() async {
    if (_currentRoomId == null || _roomData == null) return;

    // 플레이어가 2명 이상이어야 시작 가능
    List players = List.from(_roomData!['players']);
    if (players.length < 2) return;

    try {
      // 랜덤 출제자 선정
      int describerIndex = Random().nextInt(players.length);

      await _firestore.collection('game_rooms').doc(_currentRoomId).update({
        'status': 'playing',
        'describerIndex': describerIndex,
      });

      // 첫번째 라운드 세팅 (지정된 출제자로 10라운드 내내 유지)
      await _startRound(1, players[describerIndex]['uid']);
    } catch (e) {
      debugPrint('게임 시작 실패: $e');
    }
  }

  // 라운드 시작 (내부 호출)
  Future<void> _startRound(
    int roundNumber,
    String describerId, {
    String? lastResult,
  }) async {
    final theme = _roomData?['theme'] ?? '야구 용어';
    final words = _wordPacks[theme] ?? _wordPacks['야구 용어']!;
    final targetWord = words[Random().nextInt(words.length)];

    await _firestore.collection('game_rooms').doc(_currentRoomId).update({
      'currentRound': {
        'roundNumber': roundNumber,
        'describerId': describerId,
        'targetWord': targetWord,
        'targetType': 'text',
        'hintOpen': false,
        'startTime': FieldValue.serverTimestamp(),
        'lastResult': lastResult, // 이전 라운드 결과 저장
      },
    });
  }

  // 정답 제출
  Future<bool> submitAnswer(String answer) async {
    if (_currentRoomId == null || _roomData == null) return false;

    final currentRound = _roomData!['currentRound'];
    final targetWord = currentRound['targetWord'];

    if (answer.trim() == targetWord) {
      final user = _auth.currentUser;
      if (user == null) return false;

      // 점수 업데이트
      final roomRef = _firestore.collection('game_rooms').doc(_currentRoomId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        List players = List.from(snapshot.data()!['players']);

        // 정답자 점수 +10
        final winnerIndex = players.indexWhere((p) => p['uid'] == user.uid);
        if (winnerIndex != -1) {
          players[winnerIndex]['score'] =
              (players[winnerIndex]['score'] ?? 0) + 10;
        }

        // 출제자 점수 +5 (및 설명 점수 누적)
        final describerId = currentRound['describerId'];
        final describerIndex = players.indexWhere(
          (p) => p['uid'] == describerId,
        );
        if (describerIndex != -1) {
          players[describerIndex]['score'] =
              (players[describerIndex]['score'] ?? 0) + 5;
          players[describerIndex]['describerScore'] =
              (players[describerIndex]['describerScore'] ?? 0) + 1;
        }

        transaction.update(roomRef, {'players': players});
      });

      // 다음 라운드로 진행 (출제자 변경 없음)
      int nextRoundNumber = currentRound['roundNumber'] + 1;
      if (nextRoundNumber > 10) {
        await endGame();
      } else {
        await _startRound(
          nextRoundNumber,
          currentRound['describerId'],
          lastResult: 'success',
        );
      }

      return true;
    }

    return false;
  }

  // 게임종료
  Future<void> endGame() async {
    await _firestore.collection('game_rooms').doc(_currentRoomId).update({
      'status': 'finished',
    });
  }

  // 게임 다시하기 (점수 초기화 및 대기 상태로 변경)
  Future<void> restartGame() async {
    if (_currentRoomId == null || _roomData == null) return;

    try {
      final roomRef = _firestore.collection('game_rooms').doc(_currentRoomId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        List players = List.from(snapshot.data()!['players']);
        // 다음 게임 출제자 랜덤 선정
        int nextDescriberIndex = Random().nextInt(players.length);

        // 모든 플레이어 점수 초기화
        for (var i = 0; i < players.length; i++) {
          players[i]['score'] = 0;
          players[i]['describerScore'] = 0;
        }

        transaction.update(roomRef, {
          'status': 'waiting',
          'players': players,
          'describerIndex': nextDescriberIndex, // 다음 게임 출제자 변경
          'currentRound': {
            'roundNumber': 0,
            'describerId': '',
            'targetWord': '',
            'targetType': 'text',
            'hintOpen': false,
            'lastResult': null,
          },
        });
      });
    } catch (e) {
      debugPrint('게임 다시하기 실패: $e');
    }
  }

  // 라운드 건너뛰기 (시간 초과 시 다음 라운드로 진행)
  Future<void> skipRound() async {
    if (_currentRoomId == null || _roomData == null) return;

    final currentRound = _roomData!['currentRound'];
    if (currentRound == null) return;

    int nextRoundNumber = currentRound['roundNumber'] + 1;
    if (nextRoundNumber > 10) {
      await endGame();
    } else {
      await _startRound(
        nextRoundNumber,
        currentRound['describerId'],
        lastResult: 'timeout',
      );
    }
  }
}
