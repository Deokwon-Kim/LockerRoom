import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/model/ranking_user_model.dart';
import 'package:lockerroom/model/quiz_trophy_model.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/const/firestore_constants.dart';
import 'package:lockerroom/utils/quiz_tier_utils.dart';

class QuizRankingProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<RankingUserModel> _rankings = [];
  List<RankingTeamModel> _teamRankings = [];
  List<QuizTrophyModel> _trophies = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCategory = 'all';
  String _selectedSeason = QuizSeasonUtils.getCurrentSeasonId();
  String? _manualSeasonId; // Firebase에서 제어하는 시즌 ID
  bool _isAllTimeMode = false;

  List<RankingUserModel> get rankings => _rankings;
  List<RankingTeamModel> get teamRankings => _teamRankings;
  List<QuizTrophyModel> get trophies => _trophies;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;
  String get selectedSeason => _selectedSeason;
  bool get isAllTimeMode => _isAllTimeMode;

  // 모드 변경 (시즌 vs 명예의 전당)
  void setAllTimeMode(bool allTime) {
    _isAllTimeMode = allTime;
    fetchRankings(true);
  }

  // 카테고리 변경
  void setCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    fetchRankings(true);
  }

  // 시즌 변경
  void setSeason(String seasonId) {
    _selectedSeason = seasonId;
    fetchRankings(true);
  }

  // 순위 데이터 가져오기 (force: true일 때만 강제 새로고침)
  Future<void> fetchRankings([bool force = false]) async {
    if (_isLoading) return;
    if (_rankings.isNotEmpty && !force) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 0. Firebase 설정에서 활성화된 시즌 ID 가져오기 (수동 제어용)
      if (_manualSeasonId == null) {
        final configDoc = await _firestore.collection('settings').doc('quiz_settings').get();
        if (configDoc.exists) {
          _manualSeasonId = configDoc.data()?['activeSeasonId'] as String?;
          if (_manualSeasonId != null && _manualSeasonId!.isNotEmpty) {
            _selectedSeason = _manualSeasonId!;
          }
        }
      }

      Query query = _firestore.collectionGroup(FirestoreConstants.quizResultsSub);

      if (!_isAllTimeMode) {
        query = query.where('seasonId', isEqualTo: _selectedSeason);
      }

      if (_selectedCategory != 'all') {
        query = query.where('category', isEqualTo: _selectedCategory);
      }

      query = query
          .orderBy('score', descending: true)
          .orderBy('completedAt', descending: true)
          .limit(10000);

      final snapshot = await query.get();

      final Map<String, Map<String, dynamic>> userTotalScores = {};
      final Map<String, int> teamTotalScores = {
        '두산베어스': 100,
        '삼성라이온즈': 100,
        '롯데자이언츠': 100,
        '기아타이거즈': 100,
        'LG트윈스': 100,
        'SSG랜더스': 100,
        '한화이글스': 100,
        '키움히어로즈': 100,
        'NC다이노스': 100,
        'KT위즈': 100,
      };

      final DateTime teamSeasonStartDate = DateTime(2026, 2, 6, 17, 0, 0);

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String;
        final score = data['score'] as int;
        final completedAt = data['completedAt'] as Timestamp;
        String userNickName = data['userNickName'] as String? ?? '';
        if (userNickName.isEmpty) userNickName = '익명';
        final teamName = data['teamName'] as String?;

        if (!userTotalScores.containsKey(userId)) {
          userTotalScores[userId] = {
            'totalScore': score,
            'completedAt': completedAt,
            'userNickName': userNickName,
            'teamName': teamName,
          };
        } else {
          userTotalScores[userId]!['totalScore'] =
              (userTotalScores[userId]!['totalScore'] as int) + score;
          final currentCompletedAt =
              userTotalScores[userId]!['completedAt'] as Timestamp;
          if (completedAt.compareTo(currentCompletedAt) > 0) {
            userTotalScores[userId]!['completedAt'] = completedAt;
          }
        }

        if (completedAt.toDate().isAfter(teamSeasonStartDate)) {
          if (teamName != null && teamName.isNotEmpty) {
            teamTotalScores[teamName] =
                (teamTotalScores[teamName] ?? 0) + score;
          } else {
            userTotalScores[userId]!['legacyTeamScore'] =
                (userTotalScores[userId]!['legacyTeamScore'] as int? ?? 0) +
                score;
          }
        }
      }

      final sortedEntries = userTotalScores.entries.toList()
        ..sort((a, b) {
          final sComp = (b.value['totalScore'] as int).compareTo(
            a.value['totalScore'] as int,
          );
          if (sComp != 0) return sComp;
          return (b.value['completedAt'] as Timestamp).compareTo(
            a.value['completedAt'] as Timestamp,
          );
        });

      final List<RankingUserModel> tempRankings = [];

      for (int i = 0; i < sortedEntries.length; i++) {
        final entry = sortedEntries[i];
        final userId = entry.key;
        final scoreData = entry.value;
        String? teamName = scoreData['teamName'];

        if (i < 300) {
          try {
            final userDoc = await _firestore.collection('users').doc(userId).get();
            final userData = userDoc.data();
            String latestNick = userData?['userNickName'] ?? scoreData['userNickName'] ?? '익명';
            if (latestNick.isEmpty) latestNick = '익명';

            final latestTeam = userData?['team'] as String?;
            if (latestTeam != null) teamName = latestTeam;

            tempRankings.add(
              RankingUserModel(
                rank: i + 1,
                userId: userId,
                name: latestNick,
                score: scoreData['totalScore'],
                rankChange: 0,
                profileUrl: userData?['profileImage'],
                completedAt: (scoreData['completedAt'] as Timestamp).toDate(),
                teamName: teamName,
                tier: QuizTierUtils.getTierName(scoreData['totalScore'] as int),
              ),
            );
          } catch (e) {
            tempRankings.add(
              RankingUserModel(
                rank: i + 1,
                userId: userId,
                name: scoreData['userNickName'] ?? '익명',
                score: scoreData['totalScore'],
                rankChange: 0,
                profileUrl: null,
                completedAt: (scoreData['completedAt'] as Timestamp).toDate(),
                teamName: teamName,
                tier: QuizTierUtils.getTierName(scoreData['totalScore'] as int),
              ),
            );
          }
        } else {
          tempRankings.add(
            RankingUserModel(
              rank: i + 1,
              userId: userId,
              name: scoreData['userNickName'] ?? '익명',
              score: scoreData['totalScore'],
              rankChange: 0,
              profileUrl: null,
              completedAt: (scoreData['completedAt'] as Timestamp).toDate(),
              teamName: teamName,
              tier: QuizTierUtils.getTierName(scoreData['totalScore'] as int),
            ),
          );
        }

        final int legacyScore = scoreData['legacyTeamScore'] as int? ?? 0;
        if (legacyScore > 0 && teamName != null && teamName.isNotEmpty) {
          teamTotalScores[teamName] = (teamTotalScores[teamName] ?? 0) + legacyScore;
        }
      }

      _rankings = tempRankings.asMap().entries.map((entry) {
        final index = entry.key;
        final user = entry.value;
        int scoreDiff = index > 0 ? user.score - tempRankings[index - 1].score : 0;
        return user.copyWith(rankChange: scoreDiff);
      }).toList();

      final List<RankingTeamModel> tempTeamRankings = teamTotalScores.entries
          .map((e) => RankingTeamModel(
                rank: 0,
                teamName: e.key,
                totalScore: e.value,
                rankChange: 0,
              ))
          .toList()
        ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

      _teamRankings = tempTeamRankings.asMap().entries.map((entry) {
        final index = entry.key;
        final team = entry.value;
        int scoreDiff = index > 0 ? team.totalScore - tempTeamRankings[index - 1].totalScore : 0;
        return team.copyWith(rank: index + 1, rankChange: scoreDiff);
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '순위를 불러오는데 실패했습니다: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // 내 순위 찾기
  RankingUserModel? getMyRanking(String currentUserId) {
    try {
      return _rankings.firstWhere((user) => user.userId == currentUserId);
    } catch (e) {
      return null;
    }
  }

  // 내 팀 순위 찾기
  RankingTeamModel? getMyTeamRanking(String teamName) {
    try {
      return _teamRankings.firstWhere((team) => team.teamName == teamName);
    } catch (e) {
      return null;
    }
  }

  // --- Trophy Logic ---

  Future<void> fetchTrophies(String userId) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection(FirestoreConstants.trophies)
          .where('userId', isEqualTo: userId)
          .orderBy('earnedAt', descending: true)
          .get();

      _trophies = snapshot.docs.map((doc) => QuizTrophyModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching trophies: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveTrophy(QuizTrophyModel trophy) async {
    try {
      final existing = await _firestore
          .collection(FirestoreConstants.trophies)
          .where('userId', isEqualTo: trophy.userId)
          .where('seasonId', isEqualTo: trophy.seasonId)
          .where('type', isEqualTo: trophy.type == TrophyType.team ? 'team' : 'individual')
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        await _firestore.collection(FirestoreConstants.trophies).add(trophy.toFirestore());
        _trophies.insert(0, trophy);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error saving trophy: $e');
    }
  }
}
