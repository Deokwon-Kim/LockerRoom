import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/stadium_weather_model.dart';

class WeatherDetailPage extends StatefulWidget {
  final StadiumWeather weather;
  const WeatherDetailPage({super.key, required this.weather});

  @override
  State<WeatherDetailPage> createState() => _WeatherDetailPageState();
}

class _WeatherDetailPageState extends State<WeatherDetailPage> {
  String _getBackgroundImagePath(String stadiumName, String condition) {
    // 구장 이름을 영어 파일명으로 변환
    String englishStadium = 'defalut';
    if (stadiumName.contains('잠실'))
      englishStadium = 'jamsil';
    else if (stadiumName.contains('고척'))
      englishStadium = 'gocheok';
    else if (stadiumName.contains('인천'))
      englishStadium = 'incheon';
    else if (stadiumName.contains('수원'))
      englishStadium = 'suwon';
    else if (stadiumName.contains('대전'))
      englishStadium = 'daejeon';
    else if (stadiumName.contains('광주'))
      englishStadium = 'gwangju';
    else if (stadiumName.contains('대구'))
      englishStadium = 'daegu';
    else if (stadiumName.contains('사직'))
      englishStadium = 'sajik';
    else if (stadiumName.contains('창원'))
      englishStadium = 'changwon';
    else if (stadiumName.contains('이천'))
      englishStadium = 'icheon';
    else if (stadiumName.contains('울산'))
      englishStadium = 'ulsan';
    else if (stadiumName.contains('포항'))
      englishStadium = 'pohang';
    else if (stadiumName.contains('청주'))
      englishStadium = 'cheongju';

    String weatherCategory = 'sunny';
    final cond = condition.toLowerCase();

    if (cond.contains('rain') || cond.contains('drizzle')) {
      weatherCategory = 'rainy';
    } else if (cond.contains('cloud')) {
      weatherCategory = 'cloudy';
    } else if (cond.contains('thunder')) {
      weatherCategory = 'thunder';
    } else if (cond.contains('snow')) {
      weatherCategory = 'snow';
    }

    return 'assets/images/stadium/${englishStadium}_$weatherCategory.png';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  _getBackgroundImagePath(
                    widget.weather.stadiumName,
                    widget.weather.condition,
                  ),
                ),
                fit: BoxFit.cover,
                // 배경 이미지를 어둡게 만드는 올바른 방법: colorFilter 사용
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.1), // 0.6 정도로 조절 (1.0이면 완전 까만색)
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 10,
            child: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.arrow_back_ios, color: WHITE),
            ),
          ),
          DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 150.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text(
                        widget.weather.stadiumName,
                        style: const TextStyle(fontSize: 42),
                      ), // 제목은 조금 더 크게
                      Text(
                        widget.weather.temp.toInt().toString() + '°',
                        style: TextStyle(fontSize: 42),
                      ),

                      Text(
                        widget.weather.description,
                        style: TextStyle(fontSize: 20),
                      ),

                      Row(
                        children: [
                          Text('강수확률: '),
                          Text(widget.weather.rainChance.toString() + '%'),
                        ],
                      ),
                      Row(
                        children: [
                          Text('풍속: '),
                          Text(widget.weather.windSpeed.toString() + 'm/s'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
