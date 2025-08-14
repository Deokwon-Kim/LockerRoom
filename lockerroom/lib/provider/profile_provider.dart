import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileProvider extends ChangeNotifier {
  String? _profileImageUrl;
  String? get profileImageUrl => _profileImageUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  ProfileProvider() {
    loadProfileImage();
  }

  // Firestore에서 프로필 이미지 URL 불러오기
  Future<void> loadProfileImage() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      _profileImageUrl = doc.data()?['profileImage'];
      notifyListeners();
    } catch (e) {
      debugPrint('프로필 이미지 로드 실패: $e');
    }
  }

  // 이미지 선택
  Future<File?> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  // 프로필 사진 업로드
  Future<void> updateProfilePickture() async {
    try {
      _isLoading = true;
      notifyListeners();

      final imageFile = await _pickImage();
      if (imageFile == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Firebase Storage 경로: profiles/{uid}/{timestamp}.jpg
      final ref = FirebaseStorage.instance
          .ref()
          .child('profiles')
          .child(uid)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putFile(imageFile);
      final imageUrl = await ref.getDownloadURL();

      // Firestore에 URL 저장
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profileImage': imageUrl,
      });

      _profileImageUrl = imageUrl;
    } catch (e) {
      print('프로필 사진 업데이트 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
