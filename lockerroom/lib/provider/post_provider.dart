import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lockerroom/model/post_model.dart';

class PostProvider extends ChangeNotifier {
  File? imageFile;
  final captionController = TextEditingController();
  final List<PostModel> posts = [];

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      imageFile = File(picked.path);
      notifyListeners();
    }
  }

  void upload() {
    if (imageFile != null && captionController.text.isNotEmpty) {
      posts.insert(
        0,
        PostModel(image: imageFile!, caption: captionController.text),
      );
      imageFile = null;
      captionController.clear();
      notifyListeners();
    }
  }
}
