import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

class UploadProvider extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _mediaFiles = [];
  bool _isUploading = false;

  List<XFile> get mediaFiles => _mediaFiles;
  bool get isUploading => _isUploading;

  // 다중 이미지/ 영상 선택
  Future<void> pickMultipleMedia() async {
    final List<XFile>? pickedFiles = await _picker.pickMultipleMedia();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      _mediaFiles = pickedFiles;
      notifyListeners();
    }
  }

  // 업로드
  Future<void> uploadPost(String text) async {
    final currnetUser = FirebaseAuth.instance.currentUser;
    if (currnetUser == null || _mediaFiles.isEmpty) return;

    _isUploading = true;
    notifyListeners();

    try {
      List<String> mediaUrls = [];
      for (var file in _mediaFiles) {
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${currnetUser.uid}";
        final ref = FirebaseStorage.instance.ref().child('posts/$fileName');
        await ref.putFile(File(file.path));
        final url = await ref.getDownloadURL();
        mediaUrls.add(url);
      }

      await FirebaseFirestore.instance.collection('posts').add({
        'userName': currnetUser.displayName,
        'userId': currnetUser.uid,
        'text': text,
        'mediaUrls': mediaUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'profileImageUrl': currnetUser.photoURL ?? '',
      });

      _mediaFiles.clear();
    } catch (e) {
      debugPrint('업로드 에러: $e');
    }

    _isUploading = false;
    notifyListeners();
  }
}
