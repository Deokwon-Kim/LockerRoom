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

// 직관모임 딥링크 처리
Future<void> navigateToMeetup(String meetupId) async {
  debugPrint('📍 navigateToMeetup called with ID: $meetupId');
  debugPrint('   Navigator ready: ${navigatorKey.currentState != null}');

  try {
    final doc = await FirebaseFirestore.instance
        .collection('meetups')
        .doc(meetupId)
        .get();

    if (doc.exists) {
      debugPrint('   ✅ Meetup found in Firestore');
      final meetup = MeetupModel.fromFirestore(doc);

      if (navigatorKey.currentState != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => MeetupDetailPage(meetup: meetup),
          ),
        );
        debugPrint('   ✅ Navigation pushed');
      } else {
        debugPrint('   ❌ Navigator not ready');
      }
    } else {
      debugPrint('   ❌ Meetup not found: $meetupId');
    }
  } catch (e) {
    debugPrint('   ❌ 모임 이동 실패: $e');
  }
}
