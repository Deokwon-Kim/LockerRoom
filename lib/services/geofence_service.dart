import 'package:geofencing_api/geofencing_api.dart';
import 'notification_service.dart';

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

  /// 지오펜싱 초기화 및 시작
  Future<void> initGeofencing() async {
    try {
      final geofencing = Geofencing.instance;

      // 1. 리스너 등록 (진입/이탈 감지)
      geofencing.addGeofenceStatusChangedListener((
        region,
        status,
        location,
      ) async {
        if (status == GeofenceStatus.enter) {
          final stadium = kboStadiums.firstWhere((s) => s['id'] == region.id);
          _triggerStadiumNotification(stadium['name']);
          print('🏟️ Stadium Geofence Entered: ${stadium['name']}');
        }
      });

      // 2. 구역(Region) 설정 - 500m 반경
      final regions = kboStadiums.map((stadium) {
        return GeofenceRegion.circular(
          id: stadium['id'],
          center: LatLng(stadium['lat'], stadium['lng']),
          radius: 500.0,
        );
      }).toSet();

      // 3. 서비스 설정 및 시작
      geofencing.setup(
        interval: 10000, // 10초 주기 (배터리 효율 고려)
        printsDebugLog: true,
      );

      if (!geofencing.isRunningService) {
        await geofencing.start(regions: regions);
        print(
          '✅ Stadium Geofence Manager Started with ${regions.length} stadiums.',
        );
      }
    } catch (e) {
      print('❌ Geofencing Init Error: $e');
    }
  }

  /// 직관 기록 유도 알림 발송
  static void _triggerStadiumNotification(String stadiumName) {
    NotificationService().showForegroundNotification(
      id: 999,
      title: '⚾ 경기장에 도착하셨나요?',
      body: '$stadiumName에 오신 것을 환영합니다! 오늘 경기의 직관 기록을 남겨보세요.',
      payload: 'stadium_record_page',
    );
  }
}
