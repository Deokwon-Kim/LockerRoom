import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void startForegroundGeofenceTask() {
  FlutterForegroundTask.setTaskHandler(GeofenceTaskHandler());
}

class GeofenceTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final geofencing = Geofencing.instance;
      
      // 1. 리스너 등록
      geofencing.addGeofenceStatusChangedListener((region, status, location) async {
        if (status == GeofenceStatus.enter) {
          final stadium = StadiumGeofenceManager.kboStadiums.firstWhere((s) => s['id'] == region.id);
          StadiumGeofenceManager.triggerStadiumNotification(stadium['name']);
          debugPrint('Stadium Geofence Entered (Background): ${stadium['name']}');
        }
      });

      // 2. 구역(Region) 설정 - 500m 반경
      final regions = StadiumGeofenceManager.kboStadiums.map((stadium) {
        return GeofenceRegion.circular(
          id: stadium['id'],
          center: LatLng(stadium['lat'], stadium['lng']),
          radius: 500.0,
        );
      }).toSet();

      // 3. 서비스 설정 및 시작
      geofencing.setup(
        interval: 10000, 
        printsDebugLog: true,
      );

      if (!geofencing.isRunningService) {
        // geofencing_api 2.0.0 start returns Future<void> or bool?
        // Flutter analyze says it returns bool.
        geofencing.start(regions: regions);
        debugPrint('✅ Background Geofencing Started');
      }
    } catch (e) {
      debugPrint('❌ Foreground Geofence Start Error: $e');
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // foreground task 유지용
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    await Geofencing.instance.stop(keepsRegions: false);
  }
}

/// 야구장 직관 탐지 및 알림을 담당하는 서비스
class StadiumGeofenceManager {
  // 싱글톤 패턴
  static final StadiumGeofenceManager _instance =
      StadiumGeofenceManager._internal();
  factory StadiumGeofenceManager() => _instance;
  StadiumGeofenceManager._internal();

  // KBO 주요 구장 좌표 데이터
  static const List<Map<String, dynamic>> kboStadiums = [
    {'id': 'jamsil', 'name': '잠실 야구장', 'lat': 37.512095, 'lng': 127.071902},
    {'id': 'gocheok', 'name': '고척 스카이돔', 'lat': 37.498216, 'lng': 126.867363},
    {
      'id': 'munhak',
      'name': '인천 SSG 랜더스필드',
      'lat': 37.437179,
      'lng': 126.693584,
    },
    {'id': 'suwon', 'name': '수원 KT 위즈파크', 'lat': 37.299922, 'lng': 127.009733},
    {'id': 'daejeon', 'name': '대전 한화생명 볼파크', 'lat': 36.3171, 'lng': 127.4293},
    {'id': 'gwangju', 'name': '광주 기아 챔피언스 필드', 'lat': 35.1681, 'lng': 126.8883},
    {'id': 'daegu', 'name': '대구 삼성 라이온즈 파크', 'lat': 35.8411, 'lng': 128.6811},
    {'id': 'sajik', 'name': '부산 사직 야구장', 'lat': 35.1941, 'lng': 129.0611},
    {'id': 'changwon', 'name': '창원 NC 파크', 'lat': 35.2221, 'lng': 128.5811},
  ];

  /// 지오펜싱 포그라운드 초기화 및 시작
  Future<void> initGeofencing() async {
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'geofencing_service',
          channelName: '위치 확인 및 직관 감지',
          channelDescription: '경기장 도착 여부를 확인합니다.',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          iconData: const NotificationIconData(
            resType: ResourceType.mipmap,
            resPrefix: ResourcePrefix.ic,
            name: 'launcher',
          ),
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: const ForegroundTaskOptions(
          interval: 5000,
          isOnceEvent: false,
          autoRunOnBoot: true,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );

      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning) {
        final bool result = await FlutterForegroundTask.startService(
          notificationTitle: 'LockerRoom: 경기장 도착을 기다리고 있습니다⚾️',
          notificationText: '직관 기록을 위해 위치를 확인 중입니다.',
          callback: startForegroundGeofenceTask,
        );

        if (result) {
          debugPrint('✅ Foreground Task Started.');
        } else {
          debugPrint('❌ Foreground Task Start Failed.');
        }
      }
    } catch (e) {
      debugPrint('❌ Geofencing Init Error: $e');
    }
  }

  /// 직관 기록 유도 알림 발송 (TaskHandler 내에서도 접근할 수 있게 static)
  static void triggerStadiumNotification(String stadiumName) {
    NotificationService().showForegroundNotification(
      id: 999,
      title: '⚾ 경기장에 도착하셨나요?',
      body: '$stadiumName에 오신 것을 환영합니다! 오늘 경기의 직관 기록을 남겨보세요.',
      payload: 'stadium_record_page',
    );
  }
}
