import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/model/ranking_user_model.dart';
import 'package:lockerroom/model/quiz_trophy_model.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/const/firestore_constants.dart';
import 'package:lockerroom/utils/quiz_tier_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizRankingProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<RankingUserModel> _rankings = [];
  List<RankingTeamModel> _teamRankings = [];
  List<QuizTrophyModel> _trophies = [];
  Map<String, List<RankingUserModel>> _hallOfFameBySeasons = {};
  bool _isLoading = false;
  bool _isHallOfFameLoading = false;
  String? _errorMessage;
  String _selectedCategory = 'all';
  String _selectedSeason = QuizSeasonUtils.getCurrentSeasonId();
  String? _manualSeasonId; // Firebase에서 제어하는 시즌 ID
  bool _isAllTimeMode = false;
  
  // 종합(Overall) 랭킹 별도 저장
  List<RankingUserModel> _overallRankings = [];
  List<RankingTeamModel> _overallTeamRankings = [];

  // 시즌제 도입 기준 시즌 (이 이하는 전체 표시, 이 초과는 Top 3만 표시)
  static const String _lastOpenSeason = '2026_04';

  List<RankingUserModel> get rankings => _rankings;
  List<RankingTeamModel> get teamRankings => _teamRankings;
  List<QuizTrophyModel> get trophies => _trophies;
  Map<String, List<RankingUserModel>> get hallOfFameBySeasons =>
      _hallOfFameBySeasons;
  bool get isLoading => _isLoading;
  bool get isHallOfFameLoading => _isHallOfFameLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;
  String get selectedSeason => _selectedSeason;
  bool get isAllTimeMode => _isAllTimeMode;

  // 항상 종합 순위를 반환하는 게터 (결과 화면 등에서 사용)
  List<RankingUserModel> get overallRankings => _selectedCategory == 'all' ? _rankings : _overallRankings;
  List<RankingTeamModel> get overallTeamRankings => _selectedCategory == 'all' ? _teamRankings : _overallTeamRankings;

  // userId -> 종합 티어 캐시 (카테고리 필터와 무관하게 항상 종합 점수 기반 티어 유지)
  final Map<String, String> _overallTierCache = {};
  String getOverallTier(String userId) =>
      _overallTierCache[userId] ?? 'PROSPECT';

  // userId -> 종합 점수 캐시 (티어 진행바에 사용)
  final Map<String, int> _overallScoreCache = {};
  int getOverallScore(String userId) => _overallScoreCache[userId] ?? 0;

  // userId -> 종합 순위 캐시
  final Map<String, int> _overallRankCache = {};
  int getOverallRank(String userId) => _overallRankCache[userId] ?? 0;

  // 로컬에 내 정보만 별도로 긴급 저장 (깜빡임 방지용)
  Future<void> _saveMyOverallToLocal(String userId, int score, String tier, int rank) async {
    final prefs = await SharedPreferences.getInstance();
    // 유저별 고유 키 사용 (멀티 계정 대응)
    await prefs.setInt('overall_quiz_score_$userId', score);
    await prefs.setString('overall_quiz_tier_$userId', tier);
    await prefs.setInt('overall_quiz_rank_$userId', rank);
  }

  // 로컬에서 내 정보 미리 불러오기 (초기 로딩 시 호출 가능)
  Future<void> loadMyOverallFromLocal() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      final prefs = await SharedPreferences.getInstance();
      // 유저별 고유 키로 로드
      final savedScore = prefs.getInt('overall_quiz_score_$currentUid') ?? 0;
      final savedTier = prefs.getString('overall_quiz_tier_$currentUid') ?? 'PROSPECT';
      final savedRank = prefs.getInt('overall_quiz_rank_$currentUid') ?? 0;
      
      _overallScoreCache[currentUid] = savedScore;
      _overallTierCache[currentUid] = savedTier;
      _overallRankCache[currentUid] = savedRank;
      notifyListeners();
    }
  }

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
  Future<void> setSeason(String seasonId) async {
    if (_selectedSeason == seasonId) return; // 동일 시즌이면 로직 스킵 (깜빡임 방지 핵심)

    _selectedSeason = seasonId;
    _overallTierCache.clear();
    _overallScoreCache.clear();
    _overallRankCache.clear(); // 시즌 변경 시 순위 캐시 초기화

    // 내 정보만이라도 즉시 로컬에서 복구 (깜빡임 방지)
    loadMyOverallFromLocal();

    return await fetchRankings(true);
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
        final configDoc = await _firestore
            .collection('settings')
            .doc('quiz_settings')
            .get();
        if (configDoc.exists) {
          _manualSeasonId = configDoc.data()?['activeSeasonId'] as String?;
          if (_manualSeasonId != null && _manualSeasonId!.isNotEmpty) {
            _selectedSeason = _manualSeasonId!;
          }
        }
      }

      Query query = _firestore.collectionGroup(
        FirestoreConstants.quizResultsSub,
      );

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

      // ─── 종합 티어 캐시 갱신: 카테고리 필터와 무관하게 전체 점수 기반으로 계산 ────
      if (force || _selectedCategory != 'all' || _overallTierCache.isEmpty) {
        // 'all' 카테고리가 아니거나 캐시가 비어있으면 전체 데이터를 가져옴
        final allQuery = _firestore
            .collectionGroup(FirestoreConstants.quizResultsSub)
            .where('seasonId', isEqualTo: _selectedSeason)
            .orderBy('score', descending: true)
            .orderBy('completedAt', descending: true)
            .limit(1000); // 종합 순위용으로 1000명 정도면 충분
        
        final allSnapshot = await allQuery.get();
        final Map<String, Map<String, dynamic>> allUserStats = {};
        final Map<String, int> allTeamScores = {
          '두산베어스': 0, '삼성라이온즈': 0, '롯데자이언츠': 0, '기아타이거즈': 0, 'LG트윈스': 0,
          'SSG랜더스': 0, '한화이글스': 0, '키움히어로즈': 0, 'NC다이노스': 0, 'KT위즈': 0,
        };

        for (var doc in allSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = data['userId'] as String? ?? '';
          if (uid.isEmpty) continue;

          final score = (data['score'] ?? 0) as int;
          final team = data['teamName'] as String?;
          final nick = data['userNickName'] as String? ?? '익명';
          final at = data['completedAt'] as Timestamp? ?? Timestamp.now();

          if (!allUserStats.containsKey(uid)) {
            allUserStats[uid] = {
              'totalScore': 0,
              'completedAt': at,
              'userNickName': nick,
              'teamName': team,
            };
          }
          allUserStats[uid]!['totalScore'] = (allUserStats[uid]!['totalScore'] as int) + score;
          
          if (team != null && allTeamScores.containsKey(team)) {
            allTeamScores[team] = (allTeamScores[team] ?? 0) + score;
          }
        }

        final sortedAllUsers = allUserStats.entries.toList()
          ..sort((a, b) => (b.value['totalScore'] as int).compareTo(a.value['totalScore'] as int));

        _overallRankings = sortedAllUsers.asMap().entries.map((entry) {
          final idx = entry.key;
          final val = entry.value;
          final score = val.value['totalScore'] as int;
          return RankingUserModel(
            rank: idx + 1,
            userId: val.key,
            name: val.value['userNickName'] as String,
            score: score,
            rankChange: 0,
            completedAt: (val.value['completedAt'] as Timestamp).toDate(),
            teamName: val.value['teamName'] as String?,
            tier: QuizTierUtils.getTierName(score),
          );
        }).toList();

        _overallTeamRankings = allTeamScores.entries.map((e) => RankingTeamModel(
          rank: 0,
          teamName: e.key,
          totalScore: e.value,
          rankChange: 0,
        )).toList()..sort((a, b) => b.totalScore.compareTo(a.totalScore));
        
        for(int i=0; i<_overallTeamRankings.length; i++) {
          _overallTeamRankings[i] = _overallTeamRankings[i].copyWith(rank: i+1);
        }

        // 캐시 업데이트
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        for (var user in _overallRankings) {
          _overallTierCache[user.userId] = user.tier!;
          _overallScoreCache[user.userId] = user.score;
          _overallRankCache[user.userId] = user.rank;
          if (user.userId == currentUid) {
            _saveMyOverallToLocal(user.userId, user.score, user.tier!, user.rank);
          }
        }
      }

      // ─── 유순위 제외 대상 (개발자, 테스트 계정 등) ─────────────────────────
      const List<String> EXCLUDED_USER_IDS = [
        // 이 자리에 본인의 UID를 넣으세요.
      ];

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

      // ─── Hall of Fame 모드: 4월 이후 시즌은 Top 50만 집계 ─────────────────
      if (_isAllTimeMode) {
        // Step 1: 시즌별로 (userId → 점수) 집계
        final Map<String, Map<String, int>> seasonUserScores = {};

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final userId = data['userId'] as String;

          // 제외 대상 유저 스킵
          if (EXCLUDED_USER_IDS.contains(userId)) continue;

          final score = data['score'] as int;
          final completedAt = data['completedAt'] as Timestamp;
          final seasonId = data['seasonId'] as String? ?? 'legacy';
          String userNickName = data['userNickName'] as String? ?? '';
          if (userNickName.isEmpty) userNickName = '익명';
          final teamName = data['teamName'] as String?;

          // 유저 메타데이터 초기화 (닉네임, 팀명, 최근 플레이 시각)
          if (!userTotalScores.containsKey(userId)) {
            userTotalScores[userId] = {
              'totalScore': 0,
              'completedAt': completedAt,
              'userNickName': userNickName,
              'teamName': teamName,
            };
          } else {
            final currentAt =
                userTotalScores[userId]!['completedAt'] as Timestamp;
            if (completedAt.compareTo(currentAt) > 0) {
              userTotalScores[userId]!['completedAt'] = completedAt;
            }
          }

          // 시즌별 점수 누적
          seasonUserScores.putIfAbsent(seasonId, () => {});
          seasonUserScores[seasonId]![userId] =
              (seasonUserScores[seasonId]![userId] ?? 0) + score;

          // 팀 점수는 기존 방식 그대로 집계
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

        // Step 2: 시즌별 필터 적용 후 all-time 총점 합산
        // - 2026_04(4월 통합시즌) 이하: 전체 참가자 반영 (기존 방식)
        // - 2026_04 초과(5월 이후 반기 시즌): 해당 시즌 Top 3만 반영
        const String lastOpenSeason = '2026_04';

        for (final seasonEntry in seasonUserScores.entries) {
          final seasonId = seasonEntry.key;
          final userScores = seasonEntry.value;

          final bool isRestrictedSeason =
              seasonId.compareTo(lastOpenSeason) > 0;
          final int eligibleCount = isRestrictedSeason ? 3 : userScores.length;

          // 이 시즌 내 점수 순 정렬
          final sortedUsers = userScores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          // 자격 있는 유저의 점수만 all-time 합산
          for (int i = 0; i < sortedUsers.length && i < eligibleCount; i++) {
            final userId = sortedUsers[i].key;
            final score = sortedUsers[i].value;
            if (userTotalScores.containsKey(userId)) {
              userTotalScores[userId]!['totalScore'] =
                  (userTotalScores[userId]!['totalScore'] as int) + score;
            }
          }
        }

        // ─── 시즌 모드: 기존 로직 그대로 ────────────────────────────────────────
      } else {
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

      if (_selectedCategory == 'all') {
        // all 카테고리 조회 결과를 종합 티어/점수/순위 캐시에도 저장
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        for (int i = 0; i < sortedEntries.length; i++) {
          final entry = sortedEntries[i];
          final total = entry.value['totalScore'] as int;
          final tier = QuizTierUtils.getTierName(total);
          final rank = i + 1;

          _overallTierCache[entry.key] = tier;
          _overallScoreCache[entry.key] = total;
          _overallRankCache[entry.key] = rank;

          // 내 정보면 로컬 저장소에 긴급 캐싱
          if (entry.key == currentUid) {
            _saveMyOverallToLocal(entry.key, total, tier, rank);
          }
        }
      }

      final List<RankingUserModel> tempRankings = [];

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
          teamTotalScores[teamName] =
              (teamTotalScores[teamName] ?? 0) + legacyScore;
        }
      }

      _rankings = tempRankings.asMap().entries.map((entry) {
        final index = entry.key;
        final user = entry.value;
        int scoreDiff = index > 0
            ? user.score - tempRankings[index - 1].score
            : 0;
        return user.copyWith(rankChange: scoreDiff);
      }).toList();

      if (_selectedCategory == 'all') {
        _overallRankings = List.from(_rankings);
      }

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

      if (_selectedCategory == 'all') {
        _overallTeamRankings = List.from(_teamRankings);
      }

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

  // 내 종합 순위 찾기
  RankingUserModel? getMyOverallRanking(String currentUserId) {
    try {
      return overallRankings.firstWhere((user) => user.userId == currentUserId);
    } catch (e) {
      return null;
    }
  }

  // 내 팀 종합 순위 찾기
  RankingTeamModel? getMyOverallTeamRanking(String teamName) {
    try {
      return overallTeamRankings.firstWhere((team) => team.teamName == teamName);
    } catch (e) {
      return null;
    }
  }

  // 내 팀 순위 찾기 (카테고리/시즌 필터 적용 버전)
  RankingTeamModel? getMyTeamRanking(String teamName) {
    try {
      return _teamRankings.firstWhere((team) => team.teamName == teamName);
    } catch (e) {
      return null;
    }
  }

  // --- Hall of Fame (시즌별) ---

  /// 명예의 전당: 시즌별로 그룹화된 랭킹 반환.
  /// - 2026-04 초과 시즌: Top 3만 표시 (뱃지 획득 대상)
  /// - 2026-04 이하 시즌: 전체 참가자 표시
  Future<void> fetchHallOfFameBySeasons([bool force = false]) async {
    if (_isHallOfFameLoading) return;
    if (_hallOfFameBySeasons.isNotEmpty && !force) return;

    _isHallOfFameLoading = true;
    notifyListeners();

    try {
      const List<String> excludedUserIds = [];

      final snapshot = await _firestore
          .collectionGroup(FirestoreConstants.quizResultsSub)
          .orderBy('score', descending: true)
          .orderBy('completedAt', descending: true)
          .limit(10000)
          .get();

      // Step 1: 시즌별 유저 점수 집계
      // Map<seasonId, Map<userId, {totalScore, completedAt, userNickName, teamName}>>
      final Map<String, Map<String, Map<String, dynamic>>> seasonData = {};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String;
        if (excludedUserIds.contains(userId)) continue;

        final score = data['score'] as int;
        final completedAt = data['completedAt'] as Timestamp;
        final seasonId = data['seasonId'] as String? ?? 'legacy';
        String userNickName = data['userNickName'] as String? ?? '';
        if (userNickName.isEmpty) userNickName = '익명';
        final teamName = data['teamName'] as String?;

        seasonData.putIfAbsent(seasonId, () => {});

        if (!seasonData[seasonId]!.containsKey(userId)) {
          seasonData[seasonId]![userId] = {
            'totalScore': score,
            'completedAt': completedAt,
            'userNickName': userNickName,
            'teamName': teamName,
          };
        } else {
          seasonData[seasonId]![userId]!['totalScore'] =
              (seasonData[seasonId]![userId]!['totalScore'] as int) + score;
          final currentAt =
              seasonData[seasonId]![userId]!['completedAt'] as Timestamp;
          if (completedAt.compareTo(currentAt) > 0) {
            seasonData[seasonId]![userId]!['completedAt'] = completedAt;
          }
        }
      }

      // Step 2: 시즌별로 정렬 및 표시 인원 제한 후 RankingUserModel 빌드
      final Map<String, List<RankingUserModel>> result = {};

      for (final seasonEntry in seasonData.entries) {
        final seasonId = seasonEntry.key;
        final userScores = seasonEntry.value;

        // 점수 내림차순 정렬
        final sorted = userScores.entries.toList()
          ..sort(
            (a, b) => (b.value['totalScore'] as int).compareTo(
              a.value['totalScore'] as int,
            ),
          );

        // 2026-04 초과 시즌 → Top 3, 이하 시즌 → 전체
        final bool isRestricted = seasonId.compareTo(_lastOpenSeason) > 0;
        final int limit = isRestricted ? 3 : sorted.length;

        final List<RankingUserModel> seasonRankings = [];

        for (int i = 0; i < sorted.length && i < limit; i++) {
          final userId = sorted[i].key;
          final scoreData = sorted[i].value;
          String? teamName = scoreData['teamName'];

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

            seasonRankings.add(
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
          } catch (_) {
            seasonRankings.add(
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
        }

        result[seasonId] = seasonRankings;
      }

      // 최신 시즌이 먼저 오도록 내림차순 정렬
      _hallOfFameBySeasons = Map.fromEntries(
        result.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
      );
    } catch (e) {
      debugPrint('명예의 전당 로드 실패: $e');
    } finally {
      _isHallOfFameLoading = false;
      notifyListeners();
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

      _trophies = snapshot.docs
          .map((doc) => QuizTrophyModel.fromFirestore(doc))
          .toList();
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
          .where(
            'type',
            isEqualTo: trophy.type == TrophyType.team ? 'team' : 'individual',
          )
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        await _firestore
            .collection(FirestoreConstants.trophies)
            .add(trophy.toFirestore());
        _trophies.insert(0, trophy);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error saving trophy: $e');
    }
  }
}
