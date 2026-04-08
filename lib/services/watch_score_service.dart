import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

class WatchScoreService {
  final _watch = WatchConnectivity();
  final _firestore = FirebaseFirestore.instance;
  StreamSubscription? _scoreSubScription;

  static final WatchScoreService _instance = WatchScoreService._internal();
  factory WatchScoreService() => _instance;
  WatchScoreService._internal();

  // 팀 이름 -> 에셋 파일 이름 변환 헬퍼
  String _getLogoName(String? teamName) {
    if (teamName == null) return 'default_logo';
    final Map<String, String> logoMap = {
      'LG': 'twins',
      'SSG': 'landers',
      '두산': 'bears',
      '기아': 'tigers',
      '삼성': 'lions',
      '롯데': 'giants',
      '한화': 'eagles',
      '키움': 'heroes',
      'KT': 'wiz',
      'NC': 'dinos',
    };
    return logoMap[teamName] ?? 'default_logo';
  }

  // 실시간 점수 추적 시작
  void startTracking(String gameId) {
    // 이미 구독중이면 중복 실행 방지
    _scoreSubScription?.cancel();

    print('워치 스코어 추적 시작...');

    _scoreSubScription = _firestore
        .collection('games')
        .doc(gameId)
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.exists) {
            final data = snapshot.data();
            if (data == null) return;

            // 워치로 보낼 데이터 구성
            final scoreData = {
              'homeScore': data['homeScore'] ?? 0,
              'awayScore': data['awayScore'] ?? 0,
              'inning': data['inning'] ?? '_',
              'homeLogo': _getLogoName(data['homeTeam']),
              'awayLogo': _getLogoName(data['awayTeam']),
              'status': data['status'],
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            };

            try {
              // 데이터 전송
              await _watch.updateApplicationContext(scoreData);
              print(
                '워치로 데이터 전송 성공: ${scoreData['homeScore']} : ${scoreData['awayScore']}',
              );
            } catch (e) {
              print('워치 전송 에러: $e');
            }
          }
        });
  }

  Future<void> startWithLiveGame() async {
    try {
      var querySnapshot = await _firestore
          .collection('games')
          .where('status', isEqualTo: 'LIVE')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        startTracking(querySnapshot.docs.first.id);
      } else {
        print('현재 라이브 중인 경기가 없습니다.');
      }
    } catch (e) {
      print('라이브 경기 조회 중 오류: $e');
    }
  }

  // 추적중지
  void stopTrancking() {
    _scoreSubScription?.cancel();
    _scoreSubScription = null;
  }
}
