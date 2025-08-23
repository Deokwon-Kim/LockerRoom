import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  String? _favoriteTeam;

  // Firestore users/{uid} 실시간 구독용
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  String? _listeningUserId;

  // 사용자별 프로필 이미지 캐시 (실시간 업데이트용)
  final Map<String, String?> _userProfileImages = {};

  // 게터
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSignUpSuccess => _isSignUpSuccess;
  User? get currentUser => _currentUser;
  String? get nickname => _nickname;
  String? get email => _email;
  String? get favoriteTeam => _favoriteTeam;

  // 특정 사용자의 프로필 이미지 가져오기
  String? getUserProfileImage(String userId) {
    return _userProfileImages[userId];
  }

  // 사용자 프로필 이미지 실시간 구독 시작
  void startListeningUserProfile(String userId) {
    if (_userProfileImages.containsKey(userId)) return; // 이미 구독 중이면 스킵

    _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (doc) {
            if (doc.exists) {
              final profileImage = doc.data()?['profileImage'] as String?;
              _userProfileImages[userId] = profileImage;
              // 위젯 트리 잠금 문제를 방지하기 위해 다음 프레임에서 notifyListeners 호출
              WidgetsBinding.instance.addPostFrameCallback((_) {
                notifyListeners();
              });
            }
          },
          onError: (e) {
            debugPrint('User profile image listen error for $userId: $e');
          },
        );
  }

  // 사용자 프로필 이미지 구독 해제
  void stopListeningUserProfile(String userId) {
    _userProfileImages.remove(userId);
    // 위젯 트리 잠금 문제를 방지하기 위해 다음 프레임에서 notifyListeners 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // 모든 프로필 이미지 구독 해제
  void clearAllProfileImages() {
    _userProfileImages.clear();
    // 위젯 트리 잠금 문제를 방지하기 위해 다음 프레임에서 notifyListeners 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

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
    _userSub = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (doc) {
            final data = doc.data();
            if (data != null) {
              // 우선순위: Firestore 값 -> FirebaseAuth 값
              _nickname =
                  (data['username'] as String?) ??
                  _auth.currentUser?.displayName;
              _email = (data['email'] as String?) ?? _auth.currentUser?.email;
              _favoriteTeam = data['favoriteTeam'] as String?;
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

  // 사용자 데이터 완전 초기화
  void clearUserData() {
    _currentUser = null;
    _nickname = null;
    _email = null;
    _favoriteTeam = null;
    _errorMessage = null;
    _isSignUpSuccess = false;
    _isLoading = false;
    notifyListeners();
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

  // Firebase Auth 토큰 강제 갱신
  Future<void> refreshAuthToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // 토큰 강제 갱신
        await user.getIdToken(true);
        print('Firebase Auth 토큰 갱신 완료');

        // 사용자 정보도 다시 로드
        await user.reload();
        _currentUser = _auth.currentUser;
        notifyListeners();
      }
    } catch (e) {
      print('Firebase Auth 토큰 갱신 실패: $e');
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();

    // 사용자 관련 모든 상태 초기화
    _currentUser = null;
    _nickname = null;
    _email = null;
    _errorMessage = null;
    _isSignUpSuccess = false;
    notifyListeners();
  }

  Future<void> loadNickname() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    _nickname = doc.data()?['username'];
    _email = doc.data()?['email'];
    notifyListeners();
  }

  Future<void> updateNickname(String newNickname) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'username': newNickname,
    });

    await FirebaseAuth.instance.currentUser?.updateDisplayName(newNickname);
    await FirebaseAuth.instance.currentUser?.reload();

    _currentUser = FirebaseAuth.instance.currentUser;

    _nickname = newNickname;
    notifyListeners(); // 갱신 알림
  }

  // 일반 이메일 계정 회원탈퇴
  Future<void> deleteEmailAccount(String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: '사용자가 로그인 되어 있지 않습니다.',
        );
      }

      final email = user.email;
      if (email == null) {
        throw FirebaseAuthException(
          code: 'no-email',
          message: '사용자의 이메일이 없습니다.',
        );
      }

      // 1. 재인증
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. 사용자 데이터 삭제
      await _deleteUserData(user.uid);

      // 3. Firebase Auth에서 사용자 삭제
      await user.delete();

      clearUserData();
    } on FirebaseAuthException catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 사용자 데이터 삭제 (공통 메서드)
  Future<void> _deleteUserData(String uid) async {
    try {
      // 1. Firestore에서 사용자 기본 정보 삭제
      await _firestore.collection('users').doc(uid).delete();

      // 2. 사용자의 산책 기록 삭제
      await _firestore.collection('trackingResult').doc(uid).delete();

      // 3. Firebase Storage에서 사용자 파일 삭제
      // 사용자별 폴더 구조: users/{uid}/
      try {
        final storageRef = FirebaseStorage.instance.ref().child('users/$uid');
        final listResult = await storageRef.listAll();

        // 하위 폴더들 삭제
        for (final prefix in listResult.prefixes) {
          await _deleteStorageFolder(prefix);
        }

        // 직접 파일들 삭제
        for (final item in listResult.items) {
          await item.delete();
        }
      } catch (e) {
        print('Storage 삭제 중 오류: $e');
        // Storage 삭제 실패는 치명적이지 않으므로 계속 진행
      }

      // 4. 기타 사용자 관련 컬렉션이 있다면 여기서 삭제
      // 예: 사용자 설정, 즐겨찾기 등
    } catch (e) {
      print('사용자 데이터 삭제 중 오류: $e');
      throw FirebaseException(
        plugin: 'firestore',
        message: '사용자 데이터 삭제에 실패했습니다.',
        code: 'data-deletion-failed',
      );
    }
  }

  // Storage 폴더 재귀적 삭제
  Future<void> _deleteStorageFolder(Reference folderRef) async {
    try {
      final listResult = await folderRef.listAll();

      // 하위 폴더들 재귀적 삭제
      for (final prefix in listResult.prefixes) {
        await _deleteStorageFolder(prefix);
      }

      // 파일들 삭제
      for (final item in listResult.items) {
        await item.delete();
      }
    } catch (e) {
      print('Storage 폴더 삭제 중 오류: $e');
    }
  }

  // 계정 삭제 후 상태 초기화를 위한 메서드
  void clearUserData() {
    _currentUser = null;
    _nickname = null;
    _email = null;
    notifyListeners();
  }

  Future<void> updateDisplayName(String newName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(newName);
        await user.reload();
        _currentUser = FirebaseAuth.instance.currentUser;
        notifyListeners();
      }
    } catch (e) {
      print('이름 변경 실패');
    }
  }
}
