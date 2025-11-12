import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class IntutionRecordListProvider extends ChangeNotifier {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  bool _isLoading = true;
  bool _isDescending = true;
  int? _selectedYear;

  bool get isLoading => _isLoading;
  bool get isDescending => _isDescending;
  int? get selectedYear => _selectedYear;

  List<Map<String, dynamic>> get records {
    final allRecords = _docs.map((d) => d.data()).toList();

    if (_selectedYear == null) return allRecords;

    return allRecords.where((record) {
      final date = record['date'] as String?;
      if (date == null) return false;
      return date.startsWith('$_selectedYear.');
    }).toList();
  }

  // 전체 기록에서 년도 목록 추출
  List<int> get availableYears {
    final years = <int>{};
    for (final doc in _docs) {
      final data = doc.data();
      final date = data['date'] as String?;
      if (date != null && date.length >= 4) {
        final year = int.tryParse(date.substring(0, 4));
        if (year != null) years.add(year);
      }
    }
    final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));
    return sortedYears;
  }

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
        .orderBy('date', descending: _isDescending)
        .snapshots()
        .listen((snap) {
          _docs
            ..clear()
            ..addAll(snap.docs);

          // 초기 년도 자동 설정
          if (_selectedYear == null && _docs.isNotEmpty) {
            _selectedYear = _getInitialYear();
          } else {
            // 선택된 년도의 기록이 없으면 자동으로 있는 년도로 조정
            _checkAndadjustYear();
          }
          _isLoading = false;
          notifyListeners();
        });
  }

  // 선택된 년도에 기록이 없으면 자동으로 다른 년도로 변경
  void _checkAndadjustYear() {
    if (_selectedYear == null) return;

    // 전체기록이 없으면 null로 설정
    if (_docs.isEmpty) {
      _selectedYear = null;
      return;
    }

    // 선택된 년도의 기록이 있는지 확인
    final hasRecordsInSelectedYear = _docs.any((doc) {
      final data = doc.data();
      final date = data['date'] as String?;
      if (date == null) return false;
      return date.startsWith('$_selectedYear.');
    });

    // 선택된 년도에 기록이 없으면 가장 최근 년도로 변경
    if (!hasRecordsInSelectedYear) {
      final years = availableYears;
      if (years.isNotEmpty) {
        _selectedYear = years.first; // 가장 최근 년도
      } else {
        _selectedYear = null; // 기록이 없으면 전체
      }
    }
  }

  // 초기년도 결정 로직
  int _getInitialYear() {
    // 옵션 1: 현재년도
    // return DateTime.now().year;

    // 옵션 2: 가장최근 기록년도 (현재)
    if (_docs.isEmpty) return DateTime.now().year;

    final firstDoc = _docs.first.data();
    final date = firstDoc['date'] as String?;

    if (date != null && date.length >= 4) {
      final year = int.tryParse(date.substring(0, 4));
      if (year != null) return year;
    }

    return DateTime.now().year;
  }

  void toggleSortOrder() {
    _isDescending = !_isDescending;
    subscribe();
  }

  // 년도 선택
  void setYear(int? year) {
    _selectedYear = year;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
