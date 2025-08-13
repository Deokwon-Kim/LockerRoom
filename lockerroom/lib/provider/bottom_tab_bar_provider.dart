import 'package:flutter/material.dart';

class BottomTabBarProvider extends ChangeNotifier {
  int _selectedIndex = 0; // 홈 탭부터 시작
  int get selectedIndex => _selectedIndex;

  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }
}
