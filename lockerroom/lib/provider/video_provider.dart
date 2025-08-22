import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lockerroom/model/team_model.dart';

class Video {
  final String id;
  final String title;
  final String thumbnailUrl;

  Video({required this.id, required this.title, required this.thumbnailUrl});
}

class VideoProvider with ChangeNotifier {
  bool _isLoading = false;
  List<Video> _videos = [];

  bool get isLoading => _isLoading;
  List<Video> get videos => _videos;

  Future<void> fetchTeamVideos(TeamModel team, String apiKey) async {
    _isLoading = true;
    notifyListeners();

    final apiUrl =
        'https://www.googleapis.com/youtube/v3/search'
        '?part=snippet'
        '&channelId=${team.channelId}'
        '&maxResults=5'
        '&order=date'
        '&type=video'
        '&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['items'];

        _videos = items.map((item) {
          return Video(
            id: item['id']['videoId'],
            title: item['snippet']['title'],
            thumbnailUrl: item['snippet']['thumbnails']['high']['url'],
          );
        }).toList();
      } else {
        _videos = [];
        debugPrint('API Error : ${response.body}');
      }
    } catch (e) {
      _videos = [];
      debugPrint('비디오 패치 에러: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}
