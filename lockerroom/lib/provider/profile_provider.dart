import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class ProfileProvider extends ChangeNotifier {
  File? _image;
  String? _imageUrl;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  File? get image => _image;
  String? get imageUrl => _imageUrl;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;

  // 뷰에서 바로 사용할 수 있는 표시용 이미지 게터
  ImageProvider? get currentImageProvider {
    if (_image != null) return FileImage(_image!);
    if (_imageUrl != null && _imageUrl!.isNotEmpty) return NetworkImage(_imageUrl!);
    return null;
  }

  final ImagePicker _picker = ImagePicker();

  // Firestore 구독 관리용 필드
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _listeningUserId;

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
  
  Future<String?> getProfileImageUrl(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return doc.data()?['profileImage'] as String?;
      }
      return null;
    } catch (e) {
      print('프로필 이미지 URL 가져오기 실패: $e');
      return null;
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

  // Firestore users/{userId} 문서를 실시간으로 구독 시작
  void startListening(String userId) {
    if (_listeningUserId == userId && _sub != null) {
      // 이미 같은 사용자에 대해 구독 중이면 무시
      return;
    }
    stopListening();

    _listeningUserId = userId;
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      _imageUrl = data != null ? data['profileImage'] as String? : null;
      notifyListeners();
    }, onError: (e) {
      print('프로필 이미지 스트림 에러: $e');
    });
  }

  // 스트림 구독 해제
  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _listeningUserId = null;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
