import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lockerroom/model/team_news_model.dart';
import 'package:lockerroom/page/news/team_news_detail_page.dart';
import 'package:lockerroom/page/news/team_news_list_page.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/services/navigation_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  // 싱글톤 패턴 적용
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _isTokenRefreshListening = false;

  bool get isInitialized => _isInitialized;

  // 알림 초기화 (중복 호출 안전)
  Future<void> initNotification() async {
    if (_isInitialized) return;

    const initSettingAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettingIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSetting = InitializationSettings(
      android: initSettingAndroid,
      iOS: initSettingIOS,
    );

    await notificationsPlugin.initialize(
      initSetting,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic> &&
              decoded['type'] == 'team_news') {
            handleTeamNewsData(decoded);
          }
        } catch (_) {}
      },
    );

    // 구단 주요뉴스 FCM 수신 및 탭 핸들링
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['type'] == 'team_news') {
        handleTeamNewsData(message.data);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'team_news') {
        final title = message.notification?.title ?? '[구단 속보]';
        final body =
            message.notification?.body ??
            (message.data['articleTitle'] as String?) ??
            '새로운 이적·주요뉴스가 도착했습니다.';
        showForegroundNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          payload: jsonEncode(message.data),
        );
      }
    });

    // Android 알림 채널 생성
    const androidChannel = AndroidNotificationChannel(
      'daily_channel_id',
      'Daily Notifications',
      description: 'Daily Notifications',
      importance: Importance.high,
    );

    // High Importance Channel (FCM용)
    const highImportanceChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('playball'),
    );

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(highImportanceChannel);

    _isInitialized = true;
  }

  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel_id',
        'Daily Notifications',
        sound: RawResourceAndroidNotificationSound('playball'),
        channelDescription: 'Daily Notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> showForegroundNotification({
    int id = 0,
    String? title,
    String? body,
    String? payload,
  }) async {
    await initNotification();
    return notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails(),
      payload: payload,
    );
  }

  static const Map<String, String> _teamTopicCodeMap = {
    '두산': 'doosan',
    '삼성': 'samsung',
    '롯데': 'lotte',
    '기아': 'kia',
    'kia': 'kia',
    'lg': 'lg',
    'ssg': 'ssg',
    'sk': 'ssg',
    '한화': 'hanwha',
    '키움': 'kiwoom',
    '넥센': 'kiwoom',
    'nc': 'nc',
    'kt': 'kt',
  };

  static String? topicNameForTeam(String? rawTeam) {
    if (rawTeam == null) return null;
    final key = rawTeam.trim().toLowerCase();
    for (final entry in _teamTopicCodeMap.entries) {
      if (key == entry.key || key.contains(entry.key)) {
        return 'team_news_${entry.value}';
      }
    }
    return null;
  }

  Future<void> syncTeamNewsTopic(
    String? teamSymple, {
    bool enabled = true,
  }) async {
    try {
      const prefsKey = 'subscribed_team_news_topic';
      final prefs = await SharedPreferences.getInstance();
      final prevTopic = prefs.getString(prefsKey);
      final nextTopic = enabled ? topicNameForTeam(teamSymple) : null;

      if (prevTopic != null && prevTopic.isNotEmpty && prevTopic != nextTopic) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(prevTopic);
      }

      if (nextTopic != null && nextTopic.isNotEmpty) {
        await FirebaseMessaging.instance.subscribeToTopic(nextTopic);
        await prefs.setString(prefsKey, nextTopic);
      } else {
        await prefs.remove(prefsKey);
      }
    } catch (e) {
      debugPrint('Error syncing team news topic: $e');
    }
  }

  Future<void> handleTeamNewsData(Map<String, dynamic> data) async {
    final context = navigatorKey.currentContext;
    final navState = navigatorKey.currentState;
    if (context == null || navState == null) return;

    final rawTeam = (data['teamSymple'] as String?)?.trim() ?? '';
    final articleUrl = (data['articleUrl'] as String?)?.trim();
    final articleTitle = (data['articleTitle'] as String?)?.trim();
    final teamProvider = context.read<TeamProvider>();
    final targetTeam =
        teamProvider.findTeamByName(rawTeam.isEmpty ? '두산' : rawTeam) ??
        teamProvider.selectedTeam ??
        teamProvider.getTeam('team').first;

    navState.push(
      MaterialPageRoute(
        builder: (_) => TeamNewsListPage(
          initialTeam: targetTeam,
          initialCategory: NewsCategory.transfer,
          highlightedArticleUrl: articleUrl,
        ),
      ),
    );

    if (articleUrl != null && articleUrl.isNotEmpty) {
      final uri = Uri.tryParse(articleUrl);
      if (uri != null && uri.scheme == 'https') {
        navState.push(
          MaterialPageRoute(
            builder: (_) => TeamNewsDetailPage.fromUrl(
              url: articleUrl,
              title: articleTitle,
              source: targetTeam.symplename,
              category: NewsCategory.transfer,
              teamColor: targetTeam.color,
            ),
          ),
        );
      }
    }
  }

  Future<void> updateFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[FCM_TOKEN] Skipped: currentUser is null');
        return;
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken;
        for (int i = 0; i < 5; i++) {
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken != null && apnsToken.isNotEmpty) break;
          debugPrint(
            '[FCM_TOKEN] Waiting for iOS APNs token (${i + 1}/5)...',
          );
          await Future.delayed(const Duration(milliseconds: 500));
        }
        debugPrint(
          '[FCM_TOKEN] iOS APNs token ready: ${apnsToken != null && apnsToken.isNotEmpty}',
        );
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
        final prefix = token.substring(0, math.min(12, token.length));
        debugPrint(
          '[FCM_TOKEN] Updated for uid=${user.uid}, tokenPrefix=$prefix...',
        );
      } else {
        debugPrint('[FCM_TOKEN] Failed: getToken() returned null');
      }

      // Token Refresh Listener (중복 등록 방지)
      if (!_isTokenRefreshListening) {
        _isTokenRefreshListening = true;
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          final u = FirebaseAuth.instance.currentUser;
          if (u != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(u.uid)
                .set({'fcmToken': newToken}, SetOptions(merge: true));
            final prefix = newToken.substring(0, math.min(12, newToken.length));
            debugPrint(
              '[FCM_TOKEN] Refreshed for uid=${u.uid}, tokenPrefix=$prefix...',
            );
          }
        });
      }
    } catch (e) {
      debugPrint('[FCM_TOKEN] Error updating FCM token: $e');
    }
  }
}
