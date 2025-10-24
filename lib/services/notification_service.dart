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

    await notificationsPlugin.initialize(initSetting);
    _isInitialized = true;
  }

  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel_id',
        'Daily Notifications',
        channelDescription: 'Daily Notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
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
}
