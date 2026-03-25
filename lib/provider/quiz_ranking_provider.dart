import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/model/ranking_user_model.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';

class QuizRankingProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<RankingUserModel> _rankings = [];
  List<RankingTeamModel> _teamRankings = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCategory = 'all';
  String _selectedSeason = QuizSeasonUtils.getCurrentSeasonId();
  bool _isAllTimeMode = false;

  List<RankingUserModel> get rankings => _rankings;
  List<RankingTeamModel> get teamRankings => _teamRankings;
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
    // 이미 로딩 중이면 중복 실행 방지
    if (_isLoading) return;

    // 데이터가 이미 있고 강제 새로고침이 아니면 생략
    if (_rankings.isNotEmpty && !force) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. 결과 데이터 가져오기
      Query query = _firestore.collectionGroup('results');

      // 시즌 필터 추가 (명예의 전당 모드가 아닐 때만)
      if (!_isAllTimeMode) {
        query = query.where('seasonId', isEqualTo: _selectedSeason);
      }

      // 카테고리 필터
      if (_selectedCategory != 'all') {
        query = query.where('category', isEqualTo: _selectedCategory);
      }

      // 점수 높은 순으로 정렬
      query = query
          .orderBy('score', descending: true)
          .orderBy('completedAt', descending: true)
          .limit(10000);

      final snapshot = await query.get();

      // 사용자별 총 점수 합산 및 팀 점수 집계를 위한 맵
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

        // 1-1. 개인 점수 합산
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

        // 1-2. 팀 점수 집계 (시즌제)
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

      // 정렬
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

      // 상위 300명까지 상세 정보(최신 닉네임, 프로필) 조회
      for (int i = 0; i < sortedEntries.length; i++) {
        final entry = sortedEntries[i];
        final userId = entry.key;
        final scoreData = entry.value;
        String? teamName = scoreData['teamName'];

        if (i < 300) {
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(userId)
                .get();
            final userData = userDoc.data();
            String latestNick =
                userData?['userNickName'] ?? scoreData['userNickName'] ?? '익명';
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
            ),
          );
        }

        // 팀 점수 보완
        final int legacyScore = scoreData['legacyTeamScore'] as int? ?? 0;
        if (legacyScore > 0 && teamName != null && teamName.isNotEmpty) {
          teamTotalScores[teamName] =
              (teamTotalScores[teamName] ?? 0) + legacyScore;
        }
      }

      // 점수 차이 계산 및 최종 순위 설정
      _rankings = tempRankings.asMap().entries.map((entry) {
        final index = entry.key;
        final user = entry.value;
        int scoreDiff = 0;
        if (index > 0) {
          scoreDiff = user.score - tempRankings[index - 1].score;
        }
        return user.copyWith(rankChange: scoreDiff);
      }).toList();

      // 팀 랭킹 생성 및 정렬
      final List<RankingTeamModel> tempTeamRankings =
          teamTotalScores.entries
              .map(
                (e) => RankingTeamModel(
                  rank: 0,
                  teamName: e.key,
                  totalScore: e.value,
                  rankChange: 0,
                ),
              )
              .toList()
            ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

      _teamRankings = tempTeamRankings.asMap().entries.map((entry) {
        final index = entry.key;
        final team = entry.value;
        int scoreDiff = index > 0
            ? team.totalScore - tempTeamRankings[index - 1].totalScore
            : 0;
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
}
