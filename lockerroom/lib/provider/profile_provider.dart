import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

class ProfileProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _profileImageUrl;
  String? get profileImageUrl => _profileImageUrl;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> uploadProfileImage(XFile pickedFile) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _storage.ref().child('profiles/${user.uid}.jpg');

    await ref.putFile(File(pickedFile.path));
    final url = await ref.getDownloadURL();

    await _firestore.collection('users').doc(user.uid).set({
      'profileImageUrl': null,
    }, SetOptions(merge: true));

    _profileImageUrl = url;
    notifyListeners();
  }

  Future<void> loadProfileImage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    _profileImageUrl = doc.data()?['profileImageUrl'];
    notifyListeners();
  }
}
