class StadiumWeather {
  final String stadiumName;
  final double temp;
  final String description;
  final String condition;
  final int humidity;
  final double rainChance; // 강수확률 (0.0 ~ 1.0)
  final double windSpeed;  // 풍속 (m/s)
  final DateTime updatedAt;

  StadiumWeather({
    required this.stadiumName,
    required this.temp,
    required this.description,
    required this.condition,
    required this.humidity,
    required this.rainChance,
    required this.windSpeed,
    required this.updatedAt,
  });

  factory StadiumWeather.fromJson(
    String stadiumName,
    Map<String, dynamic> json,
  ) {
    // 5일 /3시간 예보 API와 현재 날씨 API의 구조 차이를 고려한 파싱
    final weatherList = json['weather'] as List;
    final mainData = json['main'] as Map<String, dynamic>;
    final windData = json['wind'] as Map<String, dynamic>?;
    final pop = json['pop'] != null ? (json['pop'] as num).toDouble() : 0.0;

    return StadiumWeather(
      stadiumName: stadiumName,
      temp: (mainData['temp'] as num).toDouble(),
      description: weatherList.isNotEmpty ? weatherList[0]['description'] : '',
      condition: weatherList.isNotEmpty ? weatherList[0]['main'] : 'Clear',
      humidity: (mainData['humidity'] as num).toInt(),
      rainChance: pop,
      windSpeed: windData != null ? (windData['speed'] as num).toDouble() : 0.0,
      updatedAt: DateTime.now(),
    );
  }

  /// 직관지수 (0 ~ 100점)
  /// 날씨(40) + 기온(25) + 강수확률(20) + 풍속(15)
  int get jikgwanScore {
    int score = 0;

    // 1. 날씨 상태 (40점)
    switch (condition.toLowerCase()) {
      case 'clear':
        score += 40;
        break;
      case 'clouds':
        // clouds는 구름 정도에 따라 description으로 세분화
        if (description.contains('적은') || description.contains('few')) {
          score += 35;
        } else if (description.contains('분산') || description.contains('scattered')) {
          score += 28;
        } else {
          score += 20; // broken/overcast
        }
        break;
      case 'mist':
      case 'haze':
      case 'fog':
        score += 15;
        break;
      case 'drizzle':
        score += 10;
        break;
      case 'rain':
        score += 5;
        break;
      case 'snow':
        score += 5;
        break;
      case 'thunderstorm':
        score += 0;
        break;
      default:
        score += 15;
    }

    // 2. 기온 (25점) — 18~25°C 최적
    if (temp >= 18 && temp <= 25) {
      score += 25;
    } else if ((temp >= 15 && temp < 18) || (temp > 25 && temp <= 28)) {
      score += 20;
    } else if ((temp >= 12 && temp < 15) || (temp > 28 && temp <= 32)) {
      score += 12;
    } else if ((temp >= 8 && temp < 12) || (temp > 32 && temp <= 35)) {
      score += 6;
    } else {
      score += 0;
    }

    // 3. 강수확률 (20점)
    if (rainChance <= 0.1) {
      score += 20;
    } else if (rainChance <= 0.3) {
      score += 15;
    } else if (rainChance <= 0.5) {
      score += 8;
    } else if (rainChance <= 0.7) {
      score += 3;
    } else {
      score += 0;
    }

    // 4. 풍속 (15점)
    if (windSpeed < 3) {
      score += 15;
    } else if (windSpeed < 6) {
      score += 10;
    } else if (windSpeed < 10) {
      score += 5;
    } else {
      score += 0;
    }

    return score.clamp(0, 100);
  }

  /// 직관지수 등급 라벨
  String get jikgwanLabel {
    final s = jikgwanScore;
    if (s >= 85) return '최상';
    if (s >= 70) return '좋음';
    if (s >= 50) return '보통';
    if (s >= 30) return '나쁨';
    return '매우나쁨';
  }

  /// 직관지수 등급 이모지
  String get jikgwanEmoji {
    final s = jikgwanScore;
    if (s >= 85) return '☀️';
    if (s >= 70) return '🌤';
    if (s >= 50) return '⛅';
    if (s >= 30) return '🌥';
    return '🌧';
  }
}
