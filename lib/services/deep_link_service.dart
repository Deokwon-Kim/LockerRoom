import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/services/navigation_service.dart';

class DeepLinkService {
  // 싱글톤 패턴 적용
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  Uri? _lastProcessedUri;
  DateTime? _lastProcessedTime;
  bool _isInitialized = false;
  bool _initialLinkHandled = false;

  Future<void> initDeepLinks() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      // 앱이 종료된 상태에서 딥링크로 시작된 경우
      if (!_initialLinkHandled) {
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) {
          debugPrint('🏠 Handling initial deep link: $initialUri');
          _initialLinkHandled = true;
          await _handleDeepLink(initialUri);
        }
      }

      // 앱 실행 중 딥링크 수신
      _appLinks.uriLinkStream.listen((Uri uri) {
        debugPrint('📡 Stream received deep link: $uri');

        // 동일한 URI가 짧은 시간(3초로 연장) 내에 다시 들어오면 무시
        if (_lastProcessedUri == uri &&
            _lastProcessedTime != null &&
            DateTime.now().difference(_lastProcessedTime!).inSeconds < 3) {
          debugPrint('⚠️ Ignoring duplicate stream link within 3s: $uri');
          return;
        }

        _handleDeepLink(uri);
      });
    } catch (e) {
      debugPrint('Deep link error: $e');
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    _lastProcessedUri = uri;
    _lastProcessedTime = DateTime.now();

    debugPrint('🔗 Handling deep link: ${uri.toString()}');
    debugPrint('   Scheme: ${uri.scheme}');
    debugPrint('   Host: ${uri.host}');
    debugPrint('   Path: ${uri.path}');
    debugPrint('   Path segments: ${uri.pathSegments}');

    // Navigator가 준비될 때까지 대기 (최대 5초, 100ms 간격으로 체크)
    bool navigatorReady = false;
    for (int i = 0; i < 50; i++) {
      if (navigatorKey.currentState != null) {
        navigatorReady = true;
        debugPrint('   ✅ Navigator ready after ${i * 100}ms');
        break;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!navigatorReady) {
      debugPrint('   ❌ Navigator not ready after 5 seconds - aborting');
      return;
    }

    String? meetupId;

    // 1. Custom Scheme 처리: lockerroom://meetup/[ID]
    if (uri.scheme == 'lockerroom') {
      if (uri.host == 'meetup' && uri.pathSegments.isNotEmpty) {
        meetupId = uri.pathSegments[0];
      }
    }
    // 2. Universal Link 처리: https://[domain]/meetup/[ID]
    else if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'meetup') {
      if (uri.pathSegments.length >= 2) {
        meetupId = uri.pathSegments[1];
      }
    }

    if (meetupId != null) {
      debugPrint('   ✅ Navigating to meetup: $meetupId');
      await navigateToMeetup(meetupId);
    } else {
      debugPrint('   ⚠️ Unhandled or invalid deep link: ${uri.toString()}');
    }
  }
}
