import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
}
