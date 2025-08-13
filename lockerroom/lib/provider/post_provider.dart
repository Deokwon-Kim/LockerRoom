import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lockerroom/model/post_model.dart';

class PostProvider extends ChangeNotifier {
  File? imageFile; // 기존 단일 이미지 (하위 호환성을 위해 유지)
  List<File> imageFiles = []; // 여러 이미지 파일 목록
  final captionController = TextEditingController();
  final List<PostModel> posts = [];

  Future<void> pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: 80,
    );
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

  void upload() {
    if ((imageFile != null || imageFiles.isNotEmpty) && captionController.text.isNotEmpty) {
      // 여러 이미지가 있을 경우 모든 이미지를 사용하고, 아니면 단일 이미지 사용
      if (imageFiles.isNotEmpty) {
        // 모델 수정이 필요할 수 있음 - 현재 구현에 맞게 조정
        // 예시: 첫 번째 이미지만 사용
        posts.insert(
          0,
          PostModel(image: imageFiles.first, caption: captionController.text),
        );
      } else if (imageFile != null) {
        posts.insert(
          0,
          PostModel(image: imageFile!, caption: captionController.text),
        );
      }
      
      // 업로드 후 초기화
      imageFile = null;
      imageFiles.clear();
      captionController.clear();
      notifyListeners();
    }
  }
}
