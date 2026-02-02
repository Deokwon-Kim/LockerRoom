import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/services/navigation_service.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  Future<void> initDeepLinks() async {
    try {
      // 앱이 종료된 상태에서 딥링크로 시작된 경우
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleDeepLink(initialUri);
      }

      // 앱 실행 중 딥링크 수신
      _appLinks.uriLinkStream.listen((Uri uri) {
        _handleDeepLink(uri);
      });
    } catch (e) {
      debugPrint('Deep link error: $e');
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('🔗 Deep link received: ${uri.toString()}');
    debugPrint('   Path: ${uri.path}');
    debugPrint('   Path segments: ${uri.pathSegments}');

    // Navigator가 준비될 때까지 대기
    await Future.delayed(const Duration(milliseconds: 500));

    if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'meetup') {
      if (uri.pathSegments.length >= 2) {
        final meetupId = uri.pathSegments[1];
        debugPrint('   ✅ Navigating to meetup: $meetupId');
        await navigateToMeetup(meetupId);
      } else {
        debugPrint('   ❌ Invalid meetup link: no meetup ID');
      }
    } else {
      debugPrint('   ⚠️ Unhandled deep link path: ${uri.path}');
    }
  }
}
