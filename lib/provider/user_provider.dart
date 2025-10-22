import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/user_model.dart';

enum UsernameCheckState { idle, checking, available, duplicated, error }

class UserProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UsernameCheckState _state = UsernameCheckState.idle;
  UsernameCheckState get state => _state;

  String? _message;
  String? get message => _message;

  Timer? _debounce;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSignUpSuccess = false;
  User? _currentUser;
  String? _nickname;
  String? _name;
  String? _email;

  // 게터
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSignUpSuccess => _isSignUpSuccess;
  User? get currentUser => _currentUser;
  String? get nickname => _nickname;
  String? get name => _name;
  String? get email => _email;

  void onUserNameChanged(String username) {
    _debounce?.cancel();

    if (username.trim().isEmpty) {
      _state = UsernameCheckState.idle;
      _message = null;
      notifyListeners();
      return;
    }

    // 새로운 입력이 들어왔으므로 상태를 idle로 초기화
    _state = UsernameCheckState.idle;
    _message = null;
    notifyListeners();

    // 500ms 동안 입력이 멈추면 검사실행
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _checkUserName(username);
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

  Future<void> _checkUserName(String username) async {
    _state = UsernameCheckState.checking;
    _message = '중복 확인 중...';
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _state = UsernameCheckState.available;
        _message = '사용 가능한 닉네임 입니다.';
      } else {
        _state = UsernameCheckState.duplicated;
        _message = '이미 사용 중인 닉네임 입니다.';
      }
    } catch (e) {
      _state = UsernameCheckState.error;
      _message = '확인 중 오류가 발생했습니다.';
      debugPrint('닉네임 중복 확인 오류: $e');
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // 회원가입 함수
  Future<bool> signUp({
    required String email,
    required String password,
    required String checkPassword,
    required String username,
    required String name,
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
        name: name,
        useremail: email,
        uid: userCredential.user!.uid,
        followersCount: 0,
        followingCount: 0,
      );

      // Firestore에 사용자 정보 저장
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'username': user.username,
        'name': user.name,
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
    _name = null;
    _email = null;
    _errorMessage = null;
    _isSignUpSuccess = false;
    notifyListeners();
  }

  Future<void> loadNickname() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;

    await user?.reload();
    _currentUser = user;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    _nickname = doc.data()?['username'] ?? _currentUser?.displayName;
    _email = doc.data()?['email'];

    // name 필드 로드
    _name = doc.data()?['name'];

    // name이 null이면 username을 기본값으로 설정하고 Firestore에 저장
    if (_name == null && _nickname != null) {
      _name = _nickname;
      // Firestore에 name 필드 추가 (기존 사용자 마이그레이션)
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'name': _name,
        });
      } catch (e) {
        debugPrint('name 필드 업데이트 오류: $e');
      }
    }

    notifyListeners();
  }

  Future<void> loadName() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    _name = doc.data()?['name'] ?? doc.data()?['username'];
    if (_name != null) {
      notifyListeners();
    }
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

      final uid = user.uid;

      // 2. Firestore에서 사용자 데이터 삭제 (권한이 있을 때)
      await _deleteUserData(uid);

      // 3. Firebase Auth에서 사용자 삭제 (마지막)
      try {
        await user.delete();
      } catch (e) {
        print('Auth 사용자 삭제 중 오류 (무시): $e');
      }

      clearUserData();
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      print('회원탈퇴 중 오류: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 사용자 데이터 삭제 (공통 메서드)
  Future<void> _deleteUserData(String uid) async {
    try {
      print('=== 회원탈퇴 데이터 삭제 시작: $uid ===');

      // 1. 모든 Firestore 작업을 배치로 처리
      final batch = _firestore.batch();
      int batchCount = 0;
      const maxBatchSize = 400; // Firestore 배치 제한은 500

      // 1-1. 피드 댓글 삭제
      try {
        final commentsSnapshot = await _firestore
            .collection('comments')
            .where('userId', isEqualTo: uid)
            .get();
        for (final doc in commentsSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
          if (batchCount >= maxBatchSize) {
            await batch.commit();
            print('배치 커밋 (댓글): $batchCount개');
            batchCount = 0;
          }
        }
        print('피드 댓글 ${commentsSnapshot.docs.length}개 삭제됨');
      } catch (e) {
        print('피드 댓글 삭제 중 오류: $e');
      }

      // 1-2. 마켓 댓글 삭제
      try {
        final marketCommentsSnapshot = await _firestore
            .collection('marketComments')
            .where('userId', isEqualTo: uid)
            .get();
        for (final doc in marketCommentsSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
          if (batchCount >= maxBatchSize) {
            await batch.commit();
            print('배치 커밋 (마켓 댓글): $batchCount개');
            batchCount = 0;
          }
        }
        print('마켓 댓글 ${marketCommentsSnapshot.docs.length}개 삭제됨');
      } catch (e) {
        print('마켓 댓글 삭제 중 오류: $e');
      }

      // 1-3. 일반 포스트 삭제
      try {
        final postsSnapshot = await _firestore
            .collection('posts')
            .where('userId', isEqualTo: uid)
            .get();
        for (final doc in postsSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
          if (batchCount >= maxBatchSize) {
            await batch.commit();
            print('배치 커밋 (포스트): $batchCount개');
            batchCount = 0;
          }
        }
        print('피드 포스트 ${postsSnapshot.docs.length}개 삭제됨');
      } catch (e) {
        print('포스트 삭제 중 오류: $e');
      }

      // 1-4. 마켓 포스트 및 이미지 삭제
      try {
        final marketPostDoc = await _firestore
            .collection('market_posts')
            .doc(uid)
            .get();

        final List<String> imageUrls = marketPostDoc.data() != null
            ? List<String>.from(marketPostDoc.data()?['imageUrls'] ?? [])
            : [];

        if (imageUrls.isNotEmpty) {
          final storage = FirebaseStorage.instance;
          for (final imageUrl in imageUrls) {
            try {
              final imageRef = storage.refFromURL(imageUrl);
              await imageRef.delete();
            } catch (e) {
              print('Storage 이미지 삭제 실패: $e');
            }
          }
        }

        batch.delete(_firestore.collection('market_posts').doc(uid));
        batchCount++;
        print('마켓 포스트 삭제됨');
      } catch (e) {
        print('마켓 포스트 삭제 중 오류: $e');
      }

      // 1-5. 알림 삭제
      try {
        final notificationsSnapshot = await _firestore
            .collection('notifications')
            .where('toUserId', isEqualTo: uid)
            .get();
        for (final doc in notificationsSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
          if (batchCount >= maxBatchSize) {
            await batch.commit();
            print('배치 커밋 (알림): $batchCount개');
            batchCount = 0;
          }
        }
        print('알림 ${notificationsSnapshot.docs.length}개 삭제됨');
      } catch (e) {
        print('알림 삭제 중 오류: $e');
      }

      // 1-6. 신고 기록 삭제
      try {
        // 피드 신고
        final feedReportsSnapshot = await _firestore
            .collection('feed_reports')
            .where('reporterUserId', isEqualTo: uid)
            .get();
        for (final doc in feedReportsSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
        }

        final reportedFeedSnapshot = await _firestore
            .collection('feed_reports')
            .where('reportedUserId', isEqualTo: uid)
            .get();
        for (final doc in reportedFeedSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
        }

        // 피드 댓글 신고
        final feedCommentReportsSnapshot = await _firestore
            .collection('feed_comment_reports')
            .where('reporterUserId', isEqualTo: uid)
            .get();
        for (final doc in feedCommentReportsSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
        }

        final reportedFeedCommentSnapshot = await _firestore
            .collection('feed_comment_reports')
            .where('reportedUserId', isEqualTo: uid)
            .get();
        for (final doc in reportedFeedCommentSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
        }

        // 마켓 댓글 신고
        final marketCommentReportsSnapshot = await _firestore
            .collection('market_comment_reports')
            .where('reporterUserId', isEqualTo: uid)
            .get();
        for (final doc in marketCommentReportsSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
        }

        final reportedMarketCommentSnapshot = await _firestore
            .collection('market_comment_reports')
            .where('reportedUserId', isEqualTo: uid)
            .get();
        for (final doc in reportedMarketCommentSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
        }

        // 마켓 신고
        final marketReportsSnapshot = await _firestore
            .collection('market_feed_reports')
            .where('reporterUserId', isEqualTo: uid)
            .get();
        for (final doc in marketReportsSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
        }

        final reportedMarketSnapshot = await _firestore
            .collection('market_feed_reports')
            .where('reportedUserId', isEqualTo: uid)
            .get();
        for (final doc in reportedMarketSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
        }

        if (batchCount > 0) {
          await batch.commit();
          print('신고 기록 삭제 완료');
        }
        batchCount = 0;
      } catch (e) {
        print('신고 기록 삭제 중 오류: $e');
      }

      // 1-7. 팔로우/팔로워 관계 삭제 (단순 삭제만, 카운트 업데이트 안 함)
      try {
        final batch = _firestore.batch();
        batchCount = 0;

        // Following 삭제
        final followingSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('following')
            .get();
        for (final doc in followingSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
          if (batchCount >= maxBatchSize) {
            await batch.commit();
            batchCount = 0;
          }
        }

        // Followers 삭제
        final followersSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('followers')
            .get();
        for (final doc in followersSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
          if (batchCount >= maxBatchSize) {
            await batch.commit();
            batchCount = 0;
          }
        }

        if (batchCount > 0) {
          await batch.commit();
        }
        print('팔로우/팔로워 관계 삭제 완료');
      } catch (e) {
        print('팔로우 관계 삭제 중 오류: $e');
      }

      // 1-8. 사용자 문서 및 서브컬렉션 삭제
      try {
        // 경기 참석 기록 삭제
        final attendancesSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('attendances')
            .get();

        final batch = _firestore.batch();
        for (final doc in attendancesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // 사용자 문서 삭제
        batch.delete(_firestore.collection('users').doc(uid));
        await batch.commit();

        print('사용자 정보 삭제됨');
      } catch (e) {
        print('사용자 문서 삭제 중 오류: $e');
      }

      // 2. Firebase Storage에서 프로필 이미지 삭제
      try {
        final storage = FirebaseStorage.instance;
        final profilesRef = storage.ref().child('profiles/$uid');
        final profilesList = await profilesRef.listAll();
        for (final item in profilesList.items) {
          await item.delete();
        }
        print('Storage 파일 삭제 완료');
      } catch (e) {
        print('Storage 삭제 중 오류: $e');
      }

      print('=== 회원탈퇴 데이터 삭제 완료: $uid ===');
    } catch (e) {
      print('사용자 데이터 삭제 중 오류: $e');
      throw FirebaseException(
        plugin: 'firestore',
        message: '사용자 데이터 삭제에 실패했습니다: ${e.toString()}',
        code: 'data-deletion-failed',
      );
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
