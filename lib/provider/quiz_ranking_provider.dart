import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/model/ranking_user_model.dart';

class QuizRankingProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<RankingUserModel> _rankings = [];
  List<RankingTeamModel> _teamRankings = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCategory = 'all';

  List<RankingUserModel> get rankings => _rankings;
  List<RankingTeamModel> get teamRankings => _teamRankings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;

  // 카테고리 변경
  void setCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
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

      final DateTime teamSeasonStartDate = DateTime(
        2026,
        2,
        6,
        17,
        0,
        0,
      ); // 리셋 시점
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String;
        final score = data['score'] as int;
        final completedAt = data['completedAt'] as Timestamp;
        final userNickName = data['userNickName'] as String? ?? '익명';
        final teamName = data['teamName'] as String?; // 퀴즈 결과에 있는 팀명 활용

        // 1-1. 개인 점수 합산 (전체 기간)
        if (!userTotalScores.containsKey(userId)) {
          // 처음 발견한 사용자
          userTotalScores[userId] = {
            'totalScore': score,
            'completedAt': completedAt,
            'userNickName': userNickName,
            'teamName': teamName, // 초기 팀 저장
          };
        } else {
          // 이미 있는 사용자 - 점수 합산
          userTotalScores[userId]!['totalScore'] =
              (userTotalScores[userId]!['totalScore'] as int) + score;

          // 최근 completedAt 유지
          final currentCompletedAt =
              userTotalScores[userId]!['completedAt'] as Timestamp;
          if (completedAt.compareTo(currentCompletedAt) > 0) {
            userTotalScores[userId]!['completedAt'] = completedAt;
          }
        }

        // 1-2. 팀 점수 집계 (시즌제 초기화: 2026-02-05 이후 데이터만 집계)
        if (completedAt.toDate().isAfter(teamSeasonStartDate) ||
            completedAt.toDate().isAtSameMomentAs(teamSeasonStartDate)) {
          // 문서에 teamName이 있으면 사용하고, 없으면 유저 정보의 최신 팀을 나중에 보완(여기서는 일단 넘어가고 아래에서 처리)
          if (teamName != null && teamName.isNotEmpty) {
            teamTotalScores[teamName] =
                (teamTotalScores[teamName] ?? 0) + score;
          } else {
            // teamName이 없는 경우 (레거시/누락), 나중에 사용자 정보와 대조하기 위해 임시 저장
            userTotalScores[userId]!['legacyTeamScore'] =
                (userTotalScores[userId]!['legacyTeamScore'] as int? ?? 0) +
                score;
          }
        }
      }

      // 3. 합산된 점수로 1차 정렬
      final sortedEntries = userTotalScores.entries.toList()
        ..sort((a, b) {
          final scoreCompare = (b.value['totalScore'] as int).compareTo(
            a.value['totalScore'] as int,
          );
          if (scoreCompare != 0) return scoreCompare;
          return (b.value['completedAt'] as Timestamp).compareTo(
            a.value['completedAt'] as Timestamp,
          );
        });

      // 4. 상위 사용자 정보 가져오기 (상위 100명만 상세 정보 조회하여 속도 개선)
      final List<RankingUserModel> tempRankings = [];

      for (int i = 0; i < sortedEntries.length; i++) {
        final entry = sortedEntries[i];
        final userId = entry.key;
        final scoreData = entry.value;
        final userTotalScore = scoreData['totalScore'] as int;
        String? teamName = scoreData['teamName'];

        // 상상위 100명만 추가 정보(최신 팀, 프로필) 페치
        if (i < 100) {
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(userId)
                .get();
            final userData = userDoc.data();
            final latestTeam = userData?['team'] as String?;
            if (latestTeam != null) teamName = latestTeam;

            tempRankings.add(
              RankingUserModel(
                rank: 0,
                userId: userId,
                name:
                    userData?['userNickName'] ??
                    scoreData['userNickName'] ??
                    '익명',
                score: userTotalScore,
                rankChange: 0,
                profileUrl: userData?['profileImage'],
                completedAt: (scoreData['completedAt'] as Timestamp).toDate(),
                teamName: teamName,
              ),
            );
          } catch (e) {
            debugPrint('상세 정보 페치 실패 ($userId): $e');
            tempRankings.add(
              RankingUserModel(
                rank: 0,
                userId: userId,
                name: scoreData['userNickName'] ?? '익명',
                score: userTotalScore,
                rankChange: 0,
                profileUrl: null,
                completedAt: (scoreData['completedAt'] as Timestamp).toDate(),
                teamName: teamName,
              ),
            );
          }
        } else {
          // 100위 밖은 결과 문서 정보로만 표시
          tempRankings.add(
            RankingUserModel(
              rank: 0,
              userId: userId,
              name: scoreData['userNickName'] ?? '익명',
              score: userTotalScore,
              rankChange: 0,
              profileUrl: null,
              completedAt: (scoreData['completedAt'] as Timestamp).toDate(),
              teamName: teamName,
            ),
          );
        }

        // 공통: 팀 점수 집계 보완 (문서에 없어서 누락된 점수를 유저의 현재 팀으로 합산)
        // 상위 100명/하위 모두에 적용되어야 함
        final int legacyScore = scoreData['legacyTeamScore'] as int? ?? 0;
        if (legacyScore > 0 && teamName != null && teamName.isNotEmpty) {
          teamTotalScores[teamName] =
              (teamTotalScores[teamName] ?? 0) + legacyScore;
        }
      }

      // 점수 순으로 최종 재정렬
      tempRankings.sort((a, b) {
        final scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) return scoreCompare;
        // 동점일 경우 최근 기록 우선
        return b.completedAt.compareTo(a.completedAt);
      });

      // 순위 부여 및 점수 차이 계산
      _rankings = tempRankings.asMap().entries.map((entry) {
        final index = entry.key;
        final user = entry.value;

        // 바로 위 순위와의 점수 차이 계산
        int scoreDiff = 0;
        if (index > 0) {
          // 2위 이하인 경우, 바로 위 순위와의 점수 차이
          scoreDiff = user.score - tempRankings[index - 1].score; // 음수로 나옴
        }

        return user.copyWith(
          rank: index + 1,
          rankChange: scoreDiff, // rankChange 필드를 점수 차이로 재활용
        );
      }).toList();

      // 팀 랭킹 정렬 및 생성 (임시 리스트)
      final List<RankingTeamModel> tempTeamRankings = [];
      teamTotalScores.forEach((teamName, score) {
        tempTeamRankings.add(
          RankingTeamModel(
            rank: 0,
            teamName: teamName,
            totalScore: score,
            rankChange: 0,
          ),
        );
      });

      // 팀 점수 순 정렬
      tempTeamRankings.sort((a, b) => b.totalScore.compareTo(a.totalScore));

      // 팀 순위 부여
      _teamRankings = tempTeamRankings.asMap().entries.map((entry) {
        final index = entry.key;
        final team = entry.value;
        int scoreDiff = 0;
        if (index > 0) {
          scoreDiff = team.totalScore - tempTeamRankings[index - 1].totalScore;
        }
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
