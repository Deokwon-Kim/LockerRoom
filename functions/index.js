const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

// Firestore 문서 생성 시 트리거
exports.sendFollowNotification = onDocumentCreated(
  {
    document: 'users/{targetUserId}/notifications/{notificationId}',
    location: 'asia-northeast3',
  },
  async (event) => {
    if (!event.data) return;

    const data = event.data.data();
    if (!data || data.type !== 'follow') return;

    const targetUserId = event.params.targetUserId;
    const fromUserId = data.fromUserId || '';

    // 대상 유저의 FCM 토큰 조회
    const targetDoc = await admin.firestore().collection('users').doc(targetUserId).get();
    const token = targetDoc.get('fcmToken');
    if (!token) return;

    // 알림 메시지 구성
    const message = {
      token,
      notification: {
        title: '새 팔로워',
        body: '누군가 당신을 팔로우했습니다.',
      },
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK', // Flutter에서 필수
        type: 'follow',
        fromUserId,
        route: 'notifications'
      },
      android: {
        notification: {
          sound: 'default',
          priority: 'high',
        },
      },
      apns: {
        headers: {
          'apns-push-type': 'alert',
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      await admin.messaging().send(message);
      console.log(`Follow notification sent to ${targetUserId}`);
    } catch (err) {
      console.error('FCM send error:', err);
      // 만료된 토큰 정리
      if (err.errorInfo?.code === 'messaging/registration-token-not-registered') {
        await admin.firestore().collection('users').doc(targetUserId).update({ fcmToken: null });
      }
    }
  }
);
