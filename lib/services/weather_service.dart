import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:lockerroom/model/stadium_weather_model.dart';

class WeatherService {
  // 구장 좌표 정보 매핑
  static const Map<String, Map<String, double>> stadiumCoords = {
    '잠실야구장': {'lat': 37.512095, 'lng': 127.071902},
    '잠실 야구장': {'lat': 37.512095, 'lng': 127.071902},
    '고척스카이돔': {'lat': 37.498216, 'lng': 126.867363},
    '고척 스카이돔': {'lat': 37.498216, 'lng': 126.867363},
    '인천SSG랜더스필드': {'lat': 37.437179, 'lng': 126.693584},
    '인천 SSG 랜더스필드': {'lat': 37.437179, 'lng': 126.693584},
    '수원KT위즈파크': {'lat': 37.299922, 'lng': 127.009733},
    '수원 KT 위즈파크': {'lat': 37.299922, 'lng': 127.009733},
    '대전한화생명볼파크': {'lat': 36.3171, 'lng': 127.4293},
    '대전 한화생명 볼파크': {'lat': 36.3171, 'lng': 127.4293},
    '한화생명이글스파크': {'lat': 36.3171, 'lng': 127.4293},
    '광주기아챔피언스필드': {'lat': 35.1681, 'lng': 126.8883},
    '광주 기아 챔피언스 필드': {'lat': 35.1681, 'lng': 126.8883},
    '대구삼성라이온즈파크': {'lat': 35.8411, 'lng': 128.6811},
    '대구 삼성 라이온즈 파크': {'lat': 35.8411, 'lng': 128.6811},
    '사직야구장': {'lat': 35.1941, 'lng': 129.0611},
    '부산 사직 야구장': {'lat': 35.1941, 'lng': 129.0611},
    '창원NC파크': {'lat': 35.2221, 'lng': 128.5811},
    '창원 NC 파크': {'lat': 35.2221, 'lng': 128.5811},
    '이천베어스파크': {'lat': 37.2281, 'lng': 127.5255},
    '울산문수야구장': {'lat': 35.5353, 'lng': 129.2561},
    '포항야구장': {'lat': 36.0121, 'lng': 129.3581},
    '청주야구장': {'lat': 36.6341, 'lng': 127.4789},
  };

  // 구장명 정규화 후 좌표 획득
  static Map<String, double>? getCoords(String name) {
    final cleanName = name.replaceAll('', '');
    for (var entry in stadiumCoords.entries) {
      if (entry.key.replaceAll(' ', '') == cleanName) {
        return entry.value;
      }
    }
    return null;
  }

  // 특정 구장의 현재 날씨 조회
  Future<StadiumWeather?> fetchCurrentWeather(String stadiumName) async {
    final coords = getCoords(stadiumName);
    if (coords == null) return null;

    final apiKey = dotenv.env['OPENWEATHER_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint('Waring: OPENWEATHER_API_KEY 가 비었습니다');
      return null;
    }

    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=${coords['lat']}&lon=${coords['lng']}&appid=$apiKey&units=metric&lang=kr',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return StadiumWeather.fromJson(stadiumName, data);
      }
    } catch (e) {
      debugPrint('Error fetching weather for $stadiumName: $e');
    }
    return null;
  }
}
