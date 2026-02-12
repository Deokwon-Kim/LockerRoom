import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

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
        // 알림 클릭 시 처리 (필요한 경우)
      },
    );

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
      iOS: DarwinNotificationDetails(sound: 'playball.wav'),
    );
  }

  Future<void> showForegroundNotification({
    int id = 0,
    String? title,
    String? body,
    String? payload,
  }) async {
    await initNotification();
    return notificationsPlugin.show(id, title, body, notificationDetails());
  }

  Future<void> updateFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
        // print('FCM Token Updated: $token');
      }

      // Token Refresh Listener
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final u = FirebaseAuth.instance.currentUser;
        if (u != null) {
          await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
            'fcmToken': newToken,
          }, SetOptions(merge: true));
        }
      });
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }
}
