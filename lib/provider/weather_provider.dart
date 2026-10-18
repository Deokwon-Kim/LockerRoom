import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/stadium_weather_model.dart';
import 'package:lockerroom/services/weather_service.dart';

class WeatherProvider with ChangeNotifier {
  final WeatherService _weatherService = WeatherService();
  final Map<String, StadiumWeather> _stadiumWeatherMap = {};
  bool _isLoading = false;
  Timer? _refreshTimer;

  bool get isLoading => _isLoading;
  Map<String, StadiumWeather> get stadiumWeatherMap => _stadiumWeatherMap;

  // 구장리스트
  static const List<String> mainStadiums = [
    '잠실 야구장',
    '고척 스카이돔',
    '인천 SSG 랜더스필드',
    '수원 KT 위즈파크',
    '대전 한화생명 볼파크',
    '광주 기아 챔피언스 필드',
    '대구 삼성 라이온즈 파크',
    '부산 사직 야구장',
    '창원 NC 파크',
  ];

  StadiumWeather? getWeatherForStadium(String stadiumName) {
    final cleanName = stadiumName.replaceAll(' ', '');
    for (var key in _stadiumWeatherMap.keys) {
      if (key.replaceAll(' ', '') == cleanName) {
        return _stadiumWeatherMap[key];
      }
    }
    return null;
  }

  // 모든 주요 구장의 현재 날씨 일괄 조회 및 갱신 (캐싱처리 포함)
  Future<void> fetchAllStadiumsWeather({bool force = false}) async {
    // 갱신 주기를 15분으로 설정하여 API 요청 낭비 방지
    if (!force && _stadiumWeatherMap.isNotEmpty) {
      final firstWeather = _stadiumWeatherMap.values.first;
      if (DateTime.now().difference(firstWeather.updatedAt).inMinutes < 15) {
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final futures = mainStadiums.map((name) async {
        final weather = await _weatherService.fetchCurrentWeather(name);
        if (weather != null) {
          _stadiumWeatherMap[name] = weather;
        }
      });
      await Future.wait(futures);
    } catch (e) {
      debugPrint('Error fetching all stadium weather: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 단일 구장 날씨만 별도로 갱신 및 조회할 때 사용(경기 카드용)
  Future<StadiumWeather?> fetchSingleWeather(String stadiumName) async {
    final cached = getWeatherForStadium(stadiumName);
    if (cached != null &&
        DateTime.now().difference(cached.updatedAt).inMinutes < 15) {
      return cached;
    }

    final weather = await _weatherService.fetchCurrentWeather(stadiumName);
    if (weather != null) {
      _stadiumWeatherMap[stadiumName] = weather;
      notifyListeners();
    }
    return weather;
  }

  // 15분마다 날씨 자동 갱신 (앱 실행 중 백그라운드에서 주기적으로 API 재호출)
  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      fetchAllStadiumsWeather(force: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
