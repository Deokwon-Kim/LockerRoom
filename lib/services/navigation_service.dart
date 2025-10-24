import 'package:flutter/material.dart';

// 전역 내비게이터 키: 컨텍스트 없이도 네비게이션 수행
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 알림 데이터 기반으로 라우팅 결정 및 이동
void navigateFromData(Map<String, dynamic> data) {
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
