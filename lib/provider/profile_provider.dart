import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class ProfileProvider extends ChangeNotifier {
  final _userCollection = FirebaseFirestore.instance.collection('users');
  File? _image;
  String? _imageUrl;
  bool _isUploading = false;
  bool _isLoading = false;
  double _uploadProgress = 0.0;

  File? get image => _image;
  String? get imageUrl => _imageUrl;
  bool get isUploading => _isUploading;
  bool get isLoading => _isLoading;
  double get uploadProgress => _uploadProgress;

  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _image = File(pickedFile.path);
      notifyListeners();
    }
  }

  Future<void> uploadImage(String userId) async {
    if (_image == null) {
      throw Exception('업로드할 이미지가 없습니다.');
    }

    _isUploading = true; // 업로드 시작
    _uploadProgress = 0.0;
    notifyListeners();

    try {
      print('프로필 이미지 업로드 시작 - userId: $userId');
      print('이미지 파일 경로: ${_image!.path}');
      print('이미지 파일 존재 여부: ${await _image!.exists()}');

      final fileName = const Uuid().v4();
      final ref = FirebaseStorage.instance.ref().child(
        'profiles/$userId/$fileName.jpg',
      );

      print('Firebase Storage 경로: profiles/$userId/$fileName.jpg');

      // Firebase Storage에 파일 업로드
      print('파일 업로드 시작...');
      final uploadTask = ref.putFile(_image!);

      // 업로드 진행상황 모니터링
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        _uploadProgress = (snapshot.bytesTransferred / snapshot.totalBytes);
        _isUploading = snapshot.state == TaskState.running;
        notifyListeners();
        print('업로드 진행률: ${_uploadProgress * 100}%');
      });

      final snapshot = await uploadTask;
      print('파일 업로드 완료');

      // 다운로드 URL 가져오기
      print('다운로드 URL 가져오는 중...');
      _imageUrl = await snapshot.ref.getDownloadURL();
      print('다운로드 URL: $_imageUrl');

      // Firestore에 프로필 이미지 URL 저장
      print('Firestore에 URL 저장 중...');
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'profileImage': _imageUrl,
      }, SetOptions(merge: true));
      print('Firestore 저장 완료');

      _image = null;
      _isUploading = false; // 업로드 완료
      _uploadProgress = 0.0;
      notifyListeners();
      print('프로필 이미지 업로드 전체 완료');
    } catch (e) {
      _isUploading = false; // 오류 시 업로드 상태 초기화
      _uploadProgress = 0.0;
      notifyListeners();
      print('프로필 이미지 업로드 에러: $e');
      print('에러 스택 트레이스: ${StackTrace.current}');
      throw Exception('이미지 업로드 실패: $e');
    }
  }

  // 로그인 한 유저 전용 프로필
  String? _myProfileImage;
  String? get myProfileImage => _myProfileImage;
  StreamSubscription? _myProfileSub;

  // 여러 유저 프로필 캐싱
  final Map<String, String?> _userProfiles = {};
  Map<String, String?> get userProfiles => _userProfiles;

  final Map<String, StreamSubscription> _subscriptions = {};

  // 로그인한 유저 프로필 구독
  void subscribeMyProfileImage(String userId) {
    _myProfileSub?.cancel();
    _myProfileSub = _userCollection.doc(userId).snapshots().listen((doc) {
      _myProfileImage = doc.data()?['profileImage'] as String?;
      notifyListeners();
    });
  }

  // 특정 유저 프로필 구독(피드 전용)
  void subscribeUserProfile(String userId) {
    if (_subscriptions.containsKey(userId)) return; // 이미 구독 중이면 무시

    final sub = _userCollection.doc(userId).snapshots().listen((doc) {
      _userProfiles[userId] = doc.data()?['profileImage'] as String?;
      notifyListeners();
    });

    _subscriptions[userId] = sub;
  }

  // 특정 유저 구독 해제
  void unsubscribeUserProfile(String userId) {
    _subscriptions[userId]?.cancel();
    _subscriptions.remove(userId);
    _userProfiles.remove(userId);
    notifyListeners();
  }

  // 전체 구독 정리
  void cancelAllSubscriptions() {
    _myProfileSub?.cancel();
    _subscriptions.forEach((_, sub) => sub.cancel());
    _subscriptions.clear();
    _userProfiles.clear();
  }

  @override
  void dispose() {
    cancelAllSubscriptions();
    super.dispose();
  }

  // Stream<String?> liveloadProfileImage(String userId) {
  //   return FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(userId)
  //       .snapshots()
  //       .map((doc) => doc.data()?['profileImage'] as String?);
  // }

  Future<void> loadProfileImage(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (doc.exists) {
      _imageUrl = doc.data()?['profileImage'];
      notifyListeners();
    }
  }

  Future<void> deleteProfileImage(String userId) async {
    try {
      print('프로필 이미지 삭제 시작 - userId: $userId');

      // Firestore에서 프로필 이미지 URL 제거
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'profileImage': FieldValue.delete(),
      });
      print('Firestore에서 프로필 이미지 URL 삭제 완료');

      // 기존 Firebase Storage에서 이미지 파일 삭제 (선택사항)
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(_imageUrl!);
          await ref.delete();
          print('Firebase Storage에서 이미지 파일 삭제 완료');
        } catch (e) {
          print('Firebase Storage 파일 삭제 실패 (파일이 이미 없을 수 있음): $e');
        }
      }

      // 로컬 상태 초기화
      _imageUrl = null;
      _image = null;
      notifyListeners();

      print('프로필 이미지 삭제 완료');
    } catch (e) {
      print('프로필 이미지 삭제 에러: $e');
      throw Exception('프로필 이미지 삭제 실패: $e');
    }
  }
}
