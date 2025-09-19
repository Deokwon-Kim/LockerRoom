import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class IntutionRecordListProvider extends ChangeNotifier {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  bool _isLoading = true;

  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get records => _docs.map((d) => d.data()).toList();

  void subscribe() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    _sub?.cancel();
    _isLoading = true;
    notifyListeners();

    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('attendances')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snap) {
          _docs
            ..clear()
            ..addAll(snap.docs);
          _isLoading = false;
          notifyListeners();
        });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
