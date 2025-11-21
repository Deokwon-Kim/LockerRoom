import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' hide User;

class SocialLoginProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  Future<void> kakaoLogin() async {
    if (await isKakaoTalkInstalled()) {
      try {
        var provider = OAuthProvider('oidc.thebase');
        OAuthToken token = await UserApi.instance.loginWithKakaoTalk();
        var credential = provider.credential(
          idToken: token.idToken,
          accessToken: token.accessToken,
        );

        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );

        // 현재 사용자 정보 업데이트
        _currentUser = userCredential.user;

        // Firestore에 유저 정보 저장
        if (_currentUser != null) {
          final userDoc = _firestore.collection('users').doc(_currentUser!.uid);
          final docSnapshot = await userDoc.get();

          if (!docSnapshot.exists) {
            // 최초 로그인 시에만 저정
            await userDoc.set({
              'uid': _currentUser!.uid,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        print('카카오톡으로 로그인 성공');
      } catch (error) {
        print('카카오톡으로 로그인 실패 $error');

        // 사용자가 카카오톡 설치 후 디바이스 권한 요청 화면에서 로그인을 취소한 경우,
        // 의도적인 로그인 취소로 보고 카카오계정으로 로그인 시도 없이 로그인 취소로 처리 (예: 뒤로 가기)
        if (error is PlatformException && error.code == 'CANCELED') {
          return;
        }
        // 카카오톡에 연결된 카카오계정이 없는 경우, 카카오계정으로 로그인
        try {
          var provider = OAuthProvider('oidc.thebase');
          OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
          var credential = provider.credential(
            idToken: token.idToken,
            accessToken: token.accessToken,
          );
          final userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);

          // 현재 사용자 정보 업데이트
          _currentUser = userCredential.user;

          // Firestore에 유저 정보 저장
          if (_currentUser != null) {
            final userDoc = _firestore
                .collection('users')
                .doc(_currentUser!.uid);
            final docSnapshot = await userDoc.get();

            if (!docSnapshot.exists) {
              // 최초 로그인 시에만 저정

              await userDoc.set({
                'uid': _currentUser!.uid,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }
          print('카카오계정으로 로그인 성공');
        } catch (error) {
          print('카카오계정으로 로그인 실패 $error');
        }
      }
    } else {
      try {
        var provider = OAuthProvider('oidc.thebase');
        OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
        var credential = provider.credential(
          idToken: token.idToken,
          accessToken: token.accessToken,
        );
        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );

        // 현재 사용자 정보 업데이트
        _currentUser = userCredential.user;

        // Firestore에 유저 정보 저장
        if (_currentUser != null) {
          final userDoc = _firestore.collection('users').doc(_currentUser!.uid);
          final docSnapshot = await userDoc.get();

          if (!docSnapshot.exists) {
            // 최초 로그인 시에만 저정

            await userDoc.set({
              'uid': _currentUser!.uid,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
        print('카카오계정으로 로그인 성공');
      } catch (error) {
        print('카카오계정으로 로그인 실패 $error');
      }
    }
  }

  // 구글 로그인
  Future<UserCredential> googleLogin() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        throw Exception('구글 로그인이 취소되었습니다.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase 인증
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      // 현재 사용자 정보 업데이트
      _currentUser = userCredential.user;

      // Firestore에 유저 정보 저장
      if (_currentUser != null) {
        final userDoc = _firestore.collection('users').doc(_currentUser!.uid);
        final docSnapshot = await userDoc.get();

        if (!docSnapshot.exists) {
          // 최초 로그인 시에만 저장
          await userDoc.set({
            'uid': _currentUser!.uid,
            'email': _currentUser!.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      notifyListeners();
      return userCredential;
    } catch (e) {
      debugPrint('구글 로그인 오류: $e');
      rethrow;
    }
  }

  // 구글 계정 탈퇴
  Future<void> deleteGoogleAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: '사용자가 로그인 되어 있지 않습니다.',
        );
      }

      final uid = user.uid;

      // 1. Firestore 및 Storage 데이터 삭제
      await _deleteUserData(uid);

      // 2. 구글 로그아웃 (연동 해제)
      try {
        await GoogleSignIn().signOut();
      } catch (e) {
        debugPrint('구글 로그아웃 실패(이미 해제일 수 있음): $e');
      }

      // 3. Firebase Auth 계정 삭제 (재인증 처리 포함)
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          // 재인증 필요 - 구글 로그인 다시 수행
          final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

          if (googleUser == null) {
            throw Exception('재인증이 취소되었습니다.');
          }

          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;

          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          await user.reauthenticateWithCredential(credential);
          await user.delete();
        } else {
          rethrow;
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('구글 계정 탈퇴 중 오류: $e');
      rethrow;
    }
  }

  // 사용자 데이터 삭제 (Firestore + Storage)
  Future<void> _deleteUserData(String uid) async {
    try {
      debugPrint('=== 사용자 데이터 삭제 시작: $uid ===');

      // 1. 피드 댓글 삭제
      final commentsSnapshot = await _firestore
          .collection('comments')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in commentsSnapshot.docs) {
        await doc.reference.delete();
      }

      // 2. 마켓 댓글 삭제
      final marketCommentsSnapshot = await _firestore
          .collection('marketComments')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in marketCommentsSnapshot.docs) {
        await doc.reference.delete();
      }

      // 3. 피드 포스트 삭제
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in postsSnapshot.docs) {
        await doc.reference.delete();
      }

      // 4. 마켓 포스트 삭제
      final marketPostDoc = await _firestore
          .collection('market_posts')
          .doc(uid)
          .get();
      if (marketPostDoc.exists) {
        await marketPostDoc.reference.delete();
      }

      // 5. 알림 삭제
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('toUserId', isEqualTo: uid)
          .get();
      for (final doc in notificationsSnapshot.docs) {
        await doc.reference.delete();
      }

      // 6. 팔로우/팔로워 삭제
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      for (final doc in followingSnapshot.docs) {
        await doc.reference.delete();
      }

      final followersSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('followers')
          .get();
      for (final doc in followersSnapshot.docs) {
        await doc.reference.delete();
      }

      // 7. 차단 정보 삭제
      final blockedSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('blocked')
          .get();
      for (final doc in blockedSnapshot.docs) {
        await doc.reference.delete();
      }

      // 8. 사용자 문서 삭제
      await _firestore.collection('users').doc(uid).delete();

      // 9. Storage 프로필 이미지 삭제
      try {
        final storage = FirebaseStorage.instance;
        final profilesRef = storage.ref().child('profiles/$uid');
        final profilesList = await profilesRef.listAll();
        for (final item in profilesList.items) {
          await item.delete();
        }
      } catch (e) {
        debugPrint('Storage 삭제 중 오류: $e');
      }

      debugPrint('=== 사용자 데이터 삭제 완료: $uid ===');
    } catch (e) {
      debugPrint('사용자 데이터 삭제 중 오류: $e');
      rethrow;
    }
  }
}
