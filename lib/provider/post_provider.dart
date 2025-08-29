import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:provider/provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;

class PostProvider extends ChangeNotifier {
  File? imageFile; // 기존 단일 이미지 (하위 호환성을 위해 유지)
  List<File> imageFiles = []; // 여러 이미지 파일 목록
  final captionController = TextEditingController();
  final List<PostModel> posts = [];

  // 업로드 상태 관리
  bool _isUploading = false;
  bool get isUploading => _isUploading;

  String _uploadStatus = '';
  String get uploadStatus => _uploadStatus;

  Future<void> pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);

    if (picked.isNotEmpty) {
      imageFiles = picked.map((xFile) => File(xFile.path)).toList();
      // 기존 단일 이미지도 업데이트 (첫 번째 이미지, 하위 호환성을 위해)
      imageFile = imageFiles.isNotEmpty ? imageFiles.first : null;
      notifyListeners();
    }
  }

  // 기존 단일 이미지 선택 메서드 (하위 호환성을 위해 유지)
  Future<void> pickImage() async {
    await pickImages(); // 새로운 메서드로 리다이렉트
  }

  void removeImage(int index) {
    if (index >= 0 && index < imageFiles.length) {
      imageFiles.removeAt(index);
      // 첫 번째 이미지가 제거되면 imageFile도 업데이트
      imageFile = imageFiles.isNotEmpty ? imageFiles.first : null;
      notifyListeners();
    }
  }

  void clearImages() {
    imageFiles.clear();
    imageFile = null;
    notifyListeners();
  }

  Future<void> uploadPost(BuildContext context) async {
    if (isUploading) return; // 이미 업로드 중이면 중복 실행 방지

    // 1. 업로드 전 검증
    if ((imageFile == null && imageFiles.isEmpty) ||
        captionController.text.isEmpty) {
      _uploadStatus = '이미지와 내용을 모두 입력해주세요.';
      notifyListeners();
      return;
    }

    _isUploading = true;
    _uploadStatus = '업로드를 시작합니다...';
    notifyListeners();

    try {
      // 작성자 정보 가져오기
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      // ProfileProvider는 업로드 로직에서 직접 사용하지 않으므로 제거
      final authorId = userProvider.currentUser?.uid ?? 'unknown_user';
      final authorName =
          userProvider.nickname ??
          userProvider.currentUser?.displayName ??
          '사용자';

      // 디버깅: 사용자 인증 상태 확인
      print('사용자 인증 상태: ${userProvider.currentUser != null}');
      print('사용자 ID: $authorId');
      print('사용자 이름: $authorName');

      if (userProvider.currentUser == null) {
        _uploadStatus = '로그인이 필요합니다.';
        notifyListeners();
        return;
      }

      // 작성자 프로필 이미지 URL 가져오기
      _uploadStatus = '사용자 정보를 불러오는 중...';
      notifyListeners();

      String? authorProfileImageUrl;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(authorId)
            .get();
        if (doc.exists) {
          authorProfileImageUrl = doc.data()?['profileImage'] as String?;
        }
      } catch (e) {
        print('프로필 이미지 URL 가져오기 실패: $e');
        // 프로필 이미지 로드 실패에도 게시글 업로드는 계속
      }

      // 이미지 목록 준비
      List<File> imagesToUpload = imageFiles.isNotEmpty
          ? imageFiles
          : [imageFile!];

      // 2. Firebase Storage에 이미지 업로드
      _uploadStatus = '이미지를 업로드 중입니다...';
      notifyListeners();

      List<String> imageUrls = [];
      List<String> imageStoragePaths = [];
      for (int i = 0; i < imagesToUpload.length; i++) {
        final file = imagesToUpload[i];
        final originalName = path.basename(file.path);
        final uniqueName =
            '${DateTime.now().millisecondsSinceEpoch}_${i}_$originalName';
        final storagePath = 'posts/$authorId/$uniqueName';
        final ref = FirebaseStorage.instance.ref(storagePath);

        final uploadTask = ref.putFile(file);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
        imageStoragePaths.add(storagePath);

        _uploadStatus = '${i + 1}/${imagesToUpload.length}개의 이미지 업로드 완료';
        notifyListeners();
      }

      // 3. Firestore에 게시물 데이터 저장
      _uploadStatus = '게시물 정보를 저장 중입니다...';
      notifyListeners();

      final postData = {
        'authorId': authorId,
        'authorName': authorName,
        'authorProfileImageUrl': authorProfileImageUrl,
        'imageUrls': imageUrls,
        'imageStoragePaths': imageStoragePaths,
        'caption': captionController.text,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('posts').add(postData);

      _uploadStatus = '업로드 성공!';

      // 4. 성공 시에만 로컬 상태 초기화 및 업데이트
      imageFile = null;
      imageFiles.clear();
      captionController.clear();
    } catch (e) {
      print('업로드 실패: $e');
      _uploadStatus = '업로드에 실패했습니다: $e';
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }
}
