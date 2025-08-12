import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:lockerroom/model/user_model.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSignUpSuccess = false;
  User? _currentUser;
  String? _nickname;
  String? _email;

  // Firestore users/{uid} 실시간 구독용
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  String? _listeningUserId;

  // 게터
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSignUpSuccess => _isSignUpSuccess;
  User? get currentUser => _currentUser;
  String? get nickname => _nickname;
  String? get email => _email;

  // 로딩 상태 설정
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // 에러 메시지 설정
  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void setSignUpSuccess(bool success) {
    _isSignUpSuccess = success;
    notifyListeners();
  }

  // 사용자 정보 초기화
  void initializeUser() {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _nickname = _currentUser!.displayName;
      _email = _currentUser!.email;
    } else {
      _nickname = null;
      _email = null;
    }
    notifyListeners();
  }

  // Firestore users/{uid} 문서를 실시간으로 구독하여 닉네임/이메일 동기화
  void startListeningUserDoc(String userId) {
    if (_listeningUserId == userId && _userSub != null) return;
    stopListeningUserDoc();
    _listeningUserId = userId;
    _userSub = _firestore.collection('users').doc(userId).snapshots().listen(
      (doc) {
        final data = doc.data();
        if (data != null) {
          // 우선순위: Firestore 값 -> FirebaseAuth 값
          _nickname = (data['username'] as String?) ?? _auth.currentUser?.displayName;
          _email = (data['email'] as String?) ?? _auth.currentUser?.email;
          notifyListeners();
        }
      },
      onError: (e) {
        debugPrint('UserProvider Firestore listen error: $e');
      },
    );
  }

  void stopListeningUserDoc() {
    _userSub?.cancel();
    _userSub = null;
    _listeningUserId = null;
  }

  // 사용자 정보 새로고침
  Future<void> refreshUserInfo() async {
    if (_auth.currentUser != null) {
      await _auth.currentUser!.reload();
      _currentUser = _auth.currentUser;
      _nickname = _currentUser!.displayName;
      _email = _currentUser!.email;
      notifyListeners();
    }
  }

  // 회원가입 함수
  Future<bool> signUp({
    required String email,
    required String password,
    required String checkPassword,
    required String username,
  }) async {
    setLoading(true);
    setErrorMessage(null);
    try {
      // Firebase Auth 회원가입
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // 사용자 이름 업데이트
      await userCredential.user?.updateDisplayName(username.trim());
      await userCredential.user?.reload();

      // 현재 사용자 정보 업데이트
      _currentUser = FirebaseAuth.instance.currentUser;

      // UserModel 생성
      UserModel user = UserModel(
        username: username,
        useremail: email,
        uid: userCredential.user!.uid,
      );

      // Firestore에 사용자 정보 저장
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'username': user.username,
        'email': user.useremail,
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setSignUpSuccess(true);
      setErrorMessage(null);
      setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('회원가입 오류: $e');
      // 에러 코드에 따른 한글 메시지 설정
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = '이미 사용 중인 이메일 주소입니다.';
          break;
        case 'invalid-email':
          errorMessage = '유효하지 않은 이메일 형식입니다.';
          break;
        default:
          errorMessage = '회원가입 실패: ${e.message}';
          break;
      }
      setErrorMessage(errorMessage);
      setLoading(false);
      return false;
    } catch (e) {
      debugPrint('회원가입 기타 오류: $e');
      setErrorMessage('회원가입 실패: ${e.toString()}');
      setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();

    // 구독 해제 및 사용자 관련 모든 상태 초기화
    stopListeningUserDoc();
    _currentUser = null;
    _nickname = null;
    _email = null;
    _errorMessage = null;
    _isSignUpSuccess = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopListeningUserDoc();
    super.dispose();
  }
}
