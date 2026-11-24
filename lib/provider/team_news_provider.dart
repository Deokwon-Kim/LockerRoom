import 'package:flutter/material.dart';
import 'package:lockerroom/model/team_news_model.dart';
import 'package:lockerroom/services/team_news_service.dart';

class TeamNewsProvider extends ChangeNotifier {
  final TeamNewsService _service;

  TeamNewsProvider({TeamNewsService? service})
    : _service = service ?? TeamNewsService();

  static const Duration _cacheTtl = Duration(minutes: 15);

  final Map<String, List<TeamNewsModel>> _cache = {};
  final Map<String, DateTime> _lastFetchedAt = {};
  final Set<String> _loadingTeams = {};
  final Map<String, String> _errors = {};

  List<TeamNewsModel> newsForTeam(String teamSymple) {
    return _cache[teamSymple] ?? const [];
  }

  bool isLoading(String teamSymple) => _loadingTeams.contains(teamSymple);

  String? errorForTeam(String teamSymple) => _errors[teamSymple];

  DateTime? lastUpdatedAt(String teamSymple) => _lastFetchedAt[teamSymple];

  Future<void> loadTeamNews(
    String teamSymple, {
    bool forceRefresh = false,
  }) async {
    final key = teamSymple.trim();
    if (key.isEmpty) return;

    if (!forceRefresh) {
      final last = _lastFetchedAt[key];
      if (last != null &&
          DateTime.now().difference(last) < _cacheTtl &&
          (_cache[key]?.isNotEmpty ?? false)) {
        return;
      }
    }

    if (_loadingTeams.contains(key)) return;

    _loadingTeams.add(key);
    _errors.remove(key);
    notifyListeners();

    try {
      final list = await _service.fetchTeamNews(key);
      _cache[key] = list;
      _lastFetchedAt[key] = DateTime.now();
    } catch (_) {
      _errors[key] = '최신 뉴스를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
    } finally {
      _loadingTeams.remove(key);
      notifyListeners();
    }
  }
}
