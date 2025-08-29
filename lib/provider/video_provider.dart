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
  final Map<String, String> _channelIdToUploadsId = {};
  final Map<String, _CachedVideos> _cachedTeamVideos = {};

  bool get isLoading => _isLoading;
  List<Video> get videos => _videos;

  Future<void> fetchTeamVideos(TeamModel team, String apiKey) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1) Return cached videos if fresh
      final cacheKey = team.name;
      final cached = _cachedTeamVideos[cacheKey];
      final now = DateTime.now();
      if (cached != null &&
          now.difference(cached.fetchedAt) < const Duration(minutes: 60)) {
        _videos = cached.videos;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 2) Resolve uploads playlist id for the channel (cheap: 1 unit)
      final uploadsId = await _getOrFetchUploadsPlaylistId(
        team.channelId,
        apiKey,
      );
      if (uploadsId == null) {
        _videos = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 3) Fetch latest items from uploads playlist (cheap: 1 unit)
      final playlistApi =
          'https://www.googleapis.com/youtube/v3/playlistItems'
          '?part=snippet'
          '&maxResults=3'
          '&playlistId=$uploadsId'
          '&key=$apiKey';
      final response = await http.get(Uri.parse(playlistApi));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        _videos = items.map((item) {
          final snippet = item['snippet'];
          return Video(
            id: snippet['resourceId']?['videoId'] ?? '',
            title: snippet['title'],
            thumbnailUrl: snippet['thumbnails']?['high']?['url'] ?? '',
          );
        }).toList();

        // Cache result
        _cachedTeamVideos[cacheKey] = _CachedVideos(
          videos: _videos,
          fetchedAt: DateTime.now(),
        );
      } else {
        _videos = [];
        debugPrint('API Error : ${response.body}');
      }
    } catch (e) {
      _videos = [];
      debugPrint('비디오 패치 에러: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> _getOrFetchUploadsPlaylistId(
    String channelId,
    String apiKey,
  ) async {
    if (_channelIdToUploadsId.containsKey(channelId)) {
      return _channelIdToUploadsId[channelId];
    }

    final channelsApi =
        'https://www.googleapis.com/youtube/v3/channels'
        '?part=contentDetails'
        '&id=$channelId'
        '&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(channelsApi));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['items'] ?? [];
        if (items.isNotEmpty) {
          final uploadsId =
              items[0]['contentDetails']?['relatedPlaylists']?['uploads'];
          if (uploadsId is String) {
            _channelIdToUploadsId[channelId] = uploadsId;
            return uploadsId;
          }
        }
      } else {
        debugPrint('Channels API Error : ${response.body}');
      }
    } catch (e) {
      debugPrint('업로드 재생목록 조회 에러: $e');
    }
    return null;
  }
}

class _CachedVideos {
  final List<Video> videos;
  final DateTime fetchedAt;
  _CachedVideos({required this.videos, required this.fetchedAt});
}
