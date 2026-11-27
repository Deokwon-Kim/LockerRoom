import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전체 라이트/다크 테마 모드를 관리하고 로컬에 영구 저장하는 Provider
class ThemeProvider extends ChangeNotifier {
  static const String _prefKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.light;
      }
    } catch (_) {
      _themeMode = ThemeMode.light;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> toggleDarkMode(bool enabled) async {
    await setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {}
  }
}
