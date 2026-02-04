import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/page/meetup/chat_room_page.dart';
import 'package:lockerroom/page/meetup/meetup_detail_page.dart';

// 전역 내비게이터 키: 컨텍스트 없이도 네비게이션 수행
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 알림 데이터 기반으로 라우팅 결정 및 이동
Future<void> navigateFromData(Map<String, dynamic> data) async {
  final String? type = (data['type'] as String?)?.toLowerCase();

  // 1. 채팅 알림 처리
  if (type == 'chat') {
    final String? meetupId = data['meetupId'];
    if (meetupId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('meetups')
            .doc(meetupId)
            .get();

        if (doc.exists) {
          final meetup = MeetupModel.fromFirestore(doc);
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => ChatRoomPage(
                meetupId: meetup.id,
                meetupTitle: meetup.title,
                meetup: meetup,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('채팅방 이동 실패: $e');
      }
    }
    return;
  }

  // 2. 기타 알림 처리 (기존 로직)
  final String? explicitRoute = _extractRoute(data);
  if (explicitRoute == null) return;

  navigatorKey.currentState?.pushNamed(explicitRoute, arguments: data);
}

String? _extractRoute(Map<String, dynamic> data) {
  // 1) 서버에서 route가 오면 우선 사용
  final Object? routeObj = data['route'];
  if (routeObj is String && routeObj.isNotEmpty) {
    return routeObj;
  }

  // 2) type 기반 기본 매핑
  final String? type = (data['type'] as String?)?.toLowerCase();
  switch (type) {
    case 'follow':
      return 'notifications';
    default:
      return 'notifications';
  }
}

// 내비게이션 중복 방지 플래그
bool _isNavigating = false;

// 직관모임 딥링크 처리
Future<void> navigateToMeetup(String meetupId) async {
  if (_isNavigating) {
    debugPrint('   ⚠️ Already navigating, skipping: $meetupId');
    return;
  }

  debugPrint('📍 navigateToMeetup called with ID: $meetupId');

  if (navigatorKey.currentState == null) {
    debugPrint('   ❌ Navigator not ready');
    return;
  }

  _isNavigating = true;

  try {
    // 로딩 다이얼로그 없이 바로 페이지 이동 (페이지 내부에서 로딩 처리)
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => MeetupDetailPage(meetupId: meetupId),
      ),
    );
    debugPrint('   ✅ Navigation pushed (ID-based)');
  } catch (e) {
    debugPrint('   ❌ Navigation failed: $e');
  } finally {
    _isNavigating = false;
  }
}
