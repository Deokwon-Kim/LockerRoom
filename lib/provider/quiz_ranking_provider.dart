import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/model/ranking_user_model.dart';
import 'package:lockerroom/model/quiz_trophy_model.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/const/firestore_constants.dart';
import 'package:lockerroom/utils/quiz_tier_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BattingKingEntry {
  final int rank;
  final String userId;
  final String name;
  final int totalAtBats;
  final int totalHits;
  final int totalScore;
  final double seasonBattingAverage;
  final String formattedBattingAverage;
  final bool isQualifiedForBattingKing;
  final String? teamName;
  final String? profileUrl;
  final String tier;
  final int maxCombo;

  const BattingKingEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.totalAtBats,
    required this.totalHits,
    required this.totalScore,
    required this.seasonBattingAverage,
    required this.formattedBattingAverage,
    required this.isQualifiedForBattingKing,
    this.teamName,
    this.profileUrl,
    required this.tier,
    this.maxCombo = 0,
  });

  BattingKingEntry copyWith({
    String? name,
    String? teamName,
    String? profileUrl,
  }) {
    return BattingKingEntry(
      rank: rank,
      userId: userId,
      name: name ?? this.name,
      totalAtBats: totalAtBats,
      totalHits: totalHits,
      totalScore: totalScore,
      seasonBattingAverage: seasonBattingAverage,
      formattedBattingAverage: formattedBattingAverage,
      isQualifiedForBattingKing: isQualifiedForBattingKing,
      teamName: teamName ?? this.teamName,
      profileUrl: profileUrl ?? this.profileUrl,
      tier: tier,
      maxCombo: maxCombo,
    );
  }
}

class QuizRankingProvider extends ChangeNotifier {
  static const int qualifyingAtBats = 30;
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
  List<RankingUserModel> get overallRankings =>
      _selectedCategory == 'all' ? _rankings : _overallRankings;
  List<RankingTeamModel> get overallTeamRankings =>
      _selectedCategory == 'all' ? _teamRankings : _overallTeamRankings;

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

  // userId -> 시즌 누적 타수/안타 캐시 & 타격왕 랭킹
  final Map<String, int> _overallAtBatsCache = {};
  final Map<String, int> _overallHitsCache = {};
  final Map<String, int> _overallPureHitsCache = {};
  List<BattingKingEntry> _battingKingRankings = [];

  int getTotalAtBats(String userId) => _overallAtBatsCache[userId] ?? 0;
  int getTotalHits(String userId) => _overallHitsCache[userId] ?? 0;
  double getSeasonBattingAverage(String userId) {
    final ab = getTotalAtBats(userId);
    final pureHits = _overallPureHitsCache[userId] ?? getTotalHits(userId);
    return ab > 0 ? (pureHits / ab).clamp(0.0, 1.0) : 0.0;
  }

  String getFormattedSeasonBattingAverage(String userId) =>
      QuizResultModel.formatBattingAverage(
        getSeasonBattingAverage(userId),
        getTotalAtBats(userId),
      );

  bool isQualifiedForBattingKing(String userId) =>
      getTotalAtBats(userId) >= qualifyingAtBats;

  String getBattingTier(String userId) => QuizTierUtils.getTierByBattingStats(
    getTotalHits(userId),
    getSeasonBattingAverage(userId),
  );

  BattingTierProgress getBattingTierProgress(String userId) =>
      QuizTierUtils.getBattingTierProgress(
        getTotalHits(userId),
        getSeasonBattingAverage(userId),
      );

  List<BattingKingEntry> get battingKingRankings =>
      List.unmodifiable(_battingKingRankings);

  // 직전 시즌 월간 타격왕 (디펜딩 타격왕) 캐시
  String? _defendingKingUserId;
  String? _defendingKingSeasonId;
  String? _defendingKingTitle;
  double? _defendingKingAvg;
  String? _defendingTeamChampionName;
  int _myBattingKingWinCount = 0;

  // 개발자 계정 전용: 모든 오버레이/뱃지/리본/칭호/트로피 미리보기 ON/OFF
  static const String devPreviewEmail = 'kdw0032@gmail.com';
  bool _devPreviewChampionRewards = false;
  String? _devPreviewTeamName;

  static bool get isDevPreviewAccount =>
      kDebugMode || FirebaseAuth.instance.currentUser?.email == devPreviewEmail;

  bool get devPreviewChampionRewards =>
      isDevPreviewAccount && _devPreviewChampionRewards;

  int get myBattingKingWinCount => devPreviewChampionRewards
      ? (_myBattingKingWinCount > 3 ? _myBattingKingWinCount : 3)
      : _myBattingKingWinCount;

  void setDevPreviewChampionRewards(bool value, {String? teamName}) {
    if (!isDevPreviewAccount) return;
    _devPreviewChampionRewards = value;
    if (teamName != null && teamName.isNotEmpty) {
      _devPreviewTeamName = teamName;
    }
    notifyListeners();
  }

  String? get defendingKingUserId => _defendingKingUserId;
  String? get defendingKingSeasonId =>
      _defendingKingSeasonId ??
      (devPreviewChampionRewards ? QuizSeasonUtils.getCurrentSeasonId() : null);
  String? get defendingKingTitle {
    final base =
        _defendingKingTitle ??
        (devPreviewChampionRewards
            ? '${QuizSeasonUtils.getSeasonShortMonthLabel(QuizSeasonUtils.getCurrentSeasonId())} 타격왕'
            : null);
    if (base == null) return null;
    if (isDefendingBattingKing && myBattingKingWinCount > 1) {
      return '$base · 통산 ${myBattingKingWinCount}회';
    }
    return base;
  }

  /// 직전 시즌 1위가 아니더라도 통산 1회 이상 타격왕이면 영구 칭호 유지
  String? get myDisplayKingTitle {
    if (isDefendingBattingKing) return defendingKingTitle;
    if (myBattingKingWinCount > 0) {
      return '통산 ${myBattingKingWinCount}회 타격왕';
    }
    return null;
  }

  double? get defendingKingAvg => _defendingKingAvg;
  String? get defendingTeamChampionName =>
      _defendingTeamChampionName ??
      (devPreviewChampionRewards ? (_devPreviewTeamName ?? '두산 베어스') : null);
  String? get defendingTeamChampionTitle {
    final team = defendingTeamChampionName;
    final seasonId = defendingKingSeasonId;
    if (team != null && seasonId != null) {
      return '${QuizSeasonUtils.getSeasonShortCode(seasonId)} 우승 구단 팬';
    }
    return null;
  }

  bool isDefendingChampionTeam(String? teamName) {
    if (teamName == null) return false;
    if (devPreviewChampionRewards) {
      return teamName == (_devPreviewTeamName ?? teamName);
    }
    return _defendingTeamChampionName == teamName;
  }

  List<BattingKingEntry> getTeamTopContributors(
    String teamName, {
    int limit = 3,
  }) {
    final list =
        _battingKingRankings
            .where((e) => e.teamName == teamName && e.totalHits > 0)
            .toList()
          ..sort((a, b) {
            final hitsCmp = b.totalHits.compareTo(a.totalHits);
            if (hitsCmp != 0) return hitsCmp;
            return b.seasonBattingAverage.compareTo(a.seasonBattingAverage);
          });
    return list.take(limit).toList();
  }

  bool get isDefendingBattingKing {
    if (devPreviewChampionRewards) return true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && _defendingKingUserId == uid;
  }

  bool isDefendingKingUser(String uid) {
    if (devPreviewChampionRewards &&
        uid == FirebaseAuth.instance.currentUser?.uid) {
      return true;
    }
    return _defendingKingUserId != null && _defendingKingUserId == uid;
  }

  /// 월간 타격왕 판정: 규정타석(30타수+) 충족자 우선, 전원 미달 시 10타수+ 최고 타율(없으면 null)
  BattingKingEntry? getMonthlyBattingKing(List<BattingKingEntry> entries) {
    if (entries.isEmpty) return null;
    final qualified = entries
        .where((e) => e.isQualifiedForBattingKing)
        .toList();
    if (qualified.isNotEmpty) return qualified.first;
    final fallback = entries.where((e) => e.totalAtBats >= 10).toList();
    return fallback.isNotEmpty ? fallback.first : null;
  }

  Future<void> loadDefendingBattingKing([bool force = false]) async {
    final prevSeasonId = QuizSeasonUtils.getPreviousSeasonId();
    if (prevSeasonId == null) {
      _defendingKingUserId = null;
      _defendingKingSeasonId = null;
      _defendingKingTitle = null;
      _defendingKingAvg = null;
      return;
    }
    if (!force && _defendingKingSeasonId == prevSeasonId) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUid = prefs.getString('defending_king_uid_$prevSeasonId');
      if (!force && cachedUid != null && cachedUid.isNotEmpty) {
        _defendingKingUserId = cachedUid;
        _defendingKingSeasonId = prevSeasonId;
        _defendingKingTitle =
            '${QuizSeasonUtils.getSeasonShortMonthLabel(prevSeasonId)} 타격왕';
        _defendingKingAvg = prefs.getDouble('defending_king_avg_$prevSeasonId');
        notifyListeners();
        return;
      }

      final snapshot = await _firestore
          .collectionGroup(FirestoreConstants.quizResultsSub)
          .where('seasonId', isEqualTo: prevSeasonId)
          .limit(2000)
          .get();

      final Map<String, Map<String, int>> stats = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final uid = data['userId'] as String? ?? '';
        final category = data['category'] as String? ?? '';
        if (uid.isEmpty || category == '일일미션 보상') continue;

        final boxMap = data['boxScore'] is Map<String, dynamic>
            ? data['boxScore'] as Map<String, dynamic>
            : null;
        final ab =
            data['atBats'] as int? ??
            boxMap?['atBats'] as int? ??
            data['totalQuestions'] as int? ??
            0;
        final h =
            data['hits'] as int? ??
            boxMap?['hits'] as int? ??
            data['correctAnswers'] as int? ??
            0;
        final combo = boxMap?['maxCombo'] as int? ?? 0;

        stats.putIfAbsent(uid, () => {'ab': 0, 'h': 0, 'combo': 0});
        stats[uid]!['ab'] = stats[uid]!['ab']! + ab;
        stats[uid]!['h'] = stats[uid]!['h']! + h;
        if (combo > stats[uid]!['combo']!) stats[uid]!['combo'] = combo;
      }

      final entries =
          stats.entries.where((e) => e.value['ab']! > 0).map((e) {
            final ab = e.value['ab']!;
            final h = e.value['h']!;
            final avg = h / ab;
            return BattingKingEntry(
              rank: 0,
              userId: e.key,
              name: '',
              totalAtBats: ab,
              totalHits: h,
              totalScore: 0,
              seasonBattingAverage: avg,
              formattedBattingAverage: QuizResultModel.formatBattingAverage(
                avg,
                ab,
              ),
              isQualifiedForBattingKing: ab >= qualifyingAtBats,
              tier: QuizTierUtils.getTierByBattingStats(h, avg),
              maxCombo: e.value['combo']!,
            );
          }).toList()..sort((a, b) {
            if (a.isQualifiedForBattingKing != b.isQualifiedForBattingKing) {
              return b.isQualifiedForBattingKing ? 1 : -1;
            }
            final avgCmp = b.seasonBattingAverage.compareTo(
              a.seasonBattingAverage,
            );
            if (avgCmp != 0) return avgCmp;
            final comboCmp = b.maxCombo.compareTo(a.maxCombo);
            if (comboCmp != 0) return comboCmp;
            return b.totalHits.compareTo(a.totalHits);
          });

      final king = getMonthlyBattingKing(entries);
      _defendingKingSeasonId = prevSeasonId;

      // 내 통산 타격왕 우승 횟수 집계
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        try {
          final trophySnap = await _firestore
              .collection('users')
              .doc(currentUid)
              .collection('trophies')
              .get();
          int winCount = 0;
          for (final doc in trophySnap.docs) {
            final d = doc.data();
            final type = d['type'] as String? ?? '';
            final rank = d['rank'] as int? ?? 0;
            final titleLabel = d['titleLabel'] as String? ?? '';
            if (type == 'individual' &&
                (rank == 1 || titleLabel.contains('타격왕'))) {
              winCount++;
            }
          }
          _myBattingKingWinCount = winCount;
        } catch (_) {}
      }

      // 직전 시즌 구단 챔피언 집계 (최소 100타수+ 우선, 없으면 최고 타율 구단)
      final Map<String, Map<String, int>> teamStats = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final tName = data['teamName'] as String? ?? '';
        final cat = data['category'] as String? ?? '';
        if (tName.isEmpty || cat == '일일미션 보상') continue;
        final boxMap = data['boxScore'] is Map<String, dynamic>
            ? data['boxScore'] as Map<String, dynamic>
            : null;
        final ab =
            data['atBats'] as int? ??
            boxMap?['atBats'] as int? ??
            data['totalQuestions'] as int? ??
            0;
        final h =
            data['hits'] as int? ??
            boxMap?['hits'] as int? ??
            data['correctAnswers'] as int? ??
            0;
        teamStats.putIfAbsent(tName, () => {'ab': 0, 'h': 0});
        teamStats[tName]!['ab'] = teamStats[tName]!['ab']! + ab;
        teamStats[tName]!['h'] = teamStats[tName]!['h']! + h;
      }
      if (teamStats.isNotEmpty) {
        final sortedTeams =
            teamStats.entries.where((e) => e.value['ab']! > 0).toList()
              ..sort((a, b) {
                final aQual = a.value['ab']! >= 100;
                final bQual = b.value['ab']! >= 100;
                if (aQual != bQual) return bQual ? 1 : -1;
                final aAvg = a.value['h']! / a.value['ab']!;
                final bAvg = b.value['h']! / b.value['ab']!;
                final avgCmp = bAvg.compareTo(aAvg);
                if (avgCmp != 0) return avgCmp;
                return b.value['h']!.compareTo(a.value['h']!);
              });
        if (sortedTeams.isNotEmpty) {
          _defendingTeamChampionName = sortedTeams.first.key;
          await prefs.setString(
            'defending_team_champ_$prevSeasonId',
            _defendingTeamChampionName!,
          );
        }
      }

      if (king != null) {
        _defendingKingUserId = king.userId;
        _defendingKingTitle =
            '${QuizSeasonUtils.getSeasonShortMonthLabel(prevSeasonId)} 타격왕';
        _defendingKingAvg = king.seasonBattingAverage;
        await prefs.setString('defending_king_uid_$prevSeasonId', king.userId);
        await prefs.setDouble(
          'defending_king_avg_$prevSeasonId',
          king.seasonBattingAverage,
        );
      } else {
        _defendingKingUserId = null;
        _defendingKingTitle = null;
        _defendingKingAvg = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('디펜딩 타격왕 조회 실패: $e');
    }
  }

  // 로컬에 내 정보만 별도로 긴급 저장 (깜빡임 방지용, 시즌별 고유 키)
  Future<void> _saveMyOverallToLocal(
    String userId,
    int score,
    String tier,
    int rank, [
    String? seasonId,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final targetSeason = seasonId ?? _selectedSeason;

    // 유저별 + 시즌별 고유 키 사용 (멀티 계정 및 시즌 분리 대응)
    await prefs.setInt('overall_quiz_score_${targetSeason}_$userId', score);
    await prefs.setString('overall_quiz_tier_${targetSeason}_$userId', tier);
    await prefs.setInt('overall_quiz_rank_${targetSeason}_$userId', rank);
    await prefs.setString('overall_quiz_season_$userId', targetSeason);

    // 구버전 시즌 없는 단일 키가 남아있다면 제거
    if (prefs.containsKey('overall_quiz_score_$userId')) {
      await prefs.remove('overall_quiz_score_$userId');
      await prefs.remove('overall_quiz_tier_$userId');
      await prefs.remove('overall_quiz_rank_$userId');
    }
  }

  // 로컬에서 내 정보 미리 불러오기 (초기 로딩 시 호출 가능)
  Future<void> loadMyOverallFromLocal([String? seasonId]) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      final prefs = await SharedPreferences.getInstance();
      final targetSeason = seasonId ?? _selectedSeason;

      // 구버전 시즌 없는 단일 키가 남아있다면 제거
      if (prefs.containsKey('overall_quiz_score_$currentUid')) {
        await prefs.remove('overall_quiz_score_$currentUid');
        await prefs.remove('overall_quiz_tier_$currentUid');
        await prefs.remove('overall_quiz_rank_$currentUid');
      }

      // 시즌별 고유 키로 로드
      final savedScore = prefs.getInt(
        'overall_quiz_score_${targetSeason}_$currentUid',
      );
      final savedTier = prefs.getString(
        'overall_quiz_tier_${targetSeason}_$currentUid',
      );
      final savedRank = prefs.getInt(
        'overall_quiz_rank_${targetSeason}_$currentUid',
      );

      if (savedScore != null || savedTier != null) {
        _overallScoreCache[currentUid] = savedScore ?? 0;
        _overallTierCache[currentUid] = savedTier ?? 'PROSPECT';
        _overallRankCache[currentUid] = savedRank ?? 0;
      } else {
        // 새 시즌이 시작되었거나 해당 시즌에 푼 기록이 없는 경우 -> 티어/점수 초기화
        _overallScoreCache[currentUid] = 0;
        _overallTierCache[currentUid] = 'PROSPECT';
        _overallRankCache[currentUid] = 0;
      }
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
    _overallAtBatsCache.clear();
    _overallHitsCache.clear();
    _battingKingRankings = [];

    // 내 정보만이라도 즉시 로컬에서 복구 (해당 시즌 기록 없으면 PROSPECT / 0P로 초기화)
    await loadMyOverallFromLocal(seasonId);

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
            if (_selectedSeason != _manualSeasonId!) {
              _selectedSeason = _manualSeasonId!;
              await loadMyOverallFromLocal(_selectedSeason);
            }
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
          '두산베어스': 0,
          '삼성라이온즈': 0,
          '롯데자이언츠': 0,
          '기아타이거즈': 0,
          'LG트윈스': 0,
          'SSG랜더스': 0,
          '한화이글스': 0,
          '키움히어로즈': 0,
          'NC다이노스': 0,
          'KT위즈': 0,
        };
        final Map<String, int> allTeamAtBats = {
          for (final t in allTeamScores.keys) t: 0,
        };
        final Map<String, int> allTeamHits = {
          for (final t in allTeamScores.keys) t: 0,
        };

        for (var doc in allSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = data['userId'] as String? ?? '';
          if (uid.isEmpty) continue;

          final rawScore = (data['score'] ?? 0) as int;
          final mode = data['mode'] as String? ?? 'normal';
          final score = mode == 'threeOut' && rawScore > 150 ? 150 : rawScore;
          final category = data['category'] as String? ?? '';
          final team = data['teamName'] as String?;
          final nick = data['userNickName'] as String? ?? '익명';
          final at = data['completedAt'] as Timestamp? ?? Timestamp.now();
          final boxMap = data['boxScore'] is Map<String, dynamic>
              ? data['boxScore'] as Map<String, dynamic>
              : null;
          final docAtBats = category == '일일미션 보상'
              ? 0
              : (data['atBats'] as int? ??
                    boxMap?['atBats'] as int? ??
                    data['totalQuestions'] as int? ??
                    0);
          final docPureHits = category == '일일미션 보상'
              ? 0
              : (data['hits'] as int? ??
                    boxMap?['hits'] as int? ??
                    data['correctAnswers'] as int? ??
                    0);
          final docHits = category == '일일미션 보상'
              ? (data['hits'] as int? ?? boxMap?['hits'] as int? ?? 1)
              : docPureHits;

          if (!allUserStats.containsKey(uid)) {
            allUserStats[uid] = {
              'totalScore': 0,
              'totalAtBats': 0,
              'totalHits': 0,
              'pureHits': 0,
              'maxCombo': 0,
              'completedAt': at,
              'userNickName': nick,
              'teamName': team,
            };
          }
          final docCombo = boxMap?['maxCombo'] as int? ?? 0;
          final prevCombo = allUserStats[uid]!['maxCombo'] as int;
          if (docCombo > prevCombo) {
            allUserStats[uid]!['maxCombo'] = docCombo;
          }
          allUserStats[uid]!['totalScore'] =
              (allUserStats[uid]!['totalScore'] as int) + score;
          allUserStats[uid]!['totalAtBats'] =
              (allUserStats[uid]!['totalAtBats'] as int) + docAtBats;
          allUserStats[uid]!['totalHits'] =
              (allUserStats[uid]!['totalHits'] as int) + docHits;
          allUserStats[uid]!['pureHits'] =
              (allUserStats[uid]!['pureHits'] as int) + docPureHits;

          if (team != null && allTeamScores.containsKey(team)) {
            allTeamScores[team] = (allTeamScores[team] ?? 0) + score;
            allTeamAtBats[team] = (allTeamAtBats[team] ?? 0) + docAtBats;
            allTeamHits[team] = (allTeamHits[team] ?? 0) + docHits;
          }
        }

        final sortedAllUsers = allUserStats.entries.toList()
          ..sort(
            (a, b) => (b.value['totalScore'] as int).compareTo(
              a.value['totalScore'] as int,
            ),
          );

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

        // 타격왕 랭킹 빌드 (규정타석 30타수+ 우선 → 타율 내림차순 → 최대 연속 안타 → 안타 → 점수 순)
        _overallAtBatsCache.clear();
        _overallHitsCache.clear();
        _overallPureHitsCache.clear();
        final battingList = allUserStats.entries.where((e) {
          return (e.value['totalAtBats'] as int) > 0 ||
              (e.value['totalHits'] as int) > 0;
        }).toList();

        battingList.sort((a, b) {
          final aAb = a.value['totalAtBats'] as int;
          final bAb = b.value['totalAtBats'] as int;
          final aQual = aAb >= qualifyingAtBats;
          final bQual = bAb >= qualifyingAtBats;
          if (aQual != bQual) return bQual ? 1 : -1;

          final aPureHits = a.value['pureHits'] as int;
          final bPureHits = b.value['pureHits'] as int;
          final aAvg = aAb > 0 ? aPureHits / aAb : 0.0;
          final bAvg = bAb > 0 ? bPureHits / bAb : 0.0;
          final avgCmp = bAvg.compareTo(aAvg);
          if (avgCmp != 0) return avgCmp;

          final comboCmp = (b.value['maxCombo'] as int).compareTo(
            a.value['maxCombo'] as int,
          );
          if (comboCmp != 0) return comboCmp;

          final aHits = a.value['totalHits'] as int;
          final bHits = b.value['totalHits'] as int;
          final hitsCmp = bHits.compareTo(aHits);
          if (hitsCmp != 0) return hitsCmp;

          return (b.value['totalScore'] as int).compareTo(
            a.value['totalScore'] as int,
          );
        });

        _battingKingRankings = battingList.asMap().entries.map((entry) {
          final idx = entry.key;
          final uid = entry.value.key;
          final val = entry.value.value;
          final ab = val['totalAtBats'] as int;
          final h = val['totalHits'] as int;
          final pureH = val['pureHits'] as int;
          final sc = val['totalScore'] as int;
          final mc = val['maxCombo'] as int;
          final avg = ab > 0 ? pureH / ab : 0.0;
          final battingTier = QuizTierUtils.getTierByBattingStats(h, avg);

          _overallAtBatsCache[uid] = ab;
          _overallHitsCache[uid] = h;
          _overallPureHitsCache[uid] = pureH;
          _overallTierCache[uid] = battingTier;

          return BattingKingEntry(
            rank: idx + 1,
            userId: uid,
            name: val['userNickName'] as String,
            totalAtBats: ab,
            totalHits: h,
            totalScore: sc,
            seasonBattingAverage: avg,
            formattedBattingAverage: QuizResultModel.formatBattingAverage(
              avg,
              ab,
            ),
            isQualifiedForBattingKing: ab >= qualifyingAtBats,
            teamName: val['teamName'] as String?,
            tier: battingTier,
            maxCombo: mc,
          );
        }).toList();

        _overallTeamRankings =
            allTeamScores.entries
                .map(
                  (e) => RankingTeamModel(
                    rank: 0,
                    teamName: e.key,
                    totalScore: e.value,
                    rankChange: 0,
                    totalAtBats: allTeamAtBats[e.key] ?? 0,
                    totalHits: allTeamHits[e.key] ?? 0,
                  ),
                )
                .toList()
              ..sort((a, b) {
                final avgCmp = b.battingAverage.compareTo(a.battingAverage);
                if (avgCmp != 0) return avgCmp;
                final hitsCmp = b.totalHits.compareTo(a.totalHits);
                if (hitsCmp != 0) return hitsCmp;
                return b.totalScore.compareTo(a.totalScore);
              });

        for (int i = 0; i < _overallTeamRankings.length; i++) {
          _overallTeamRankings[i] = _overallTeamRankings[i].copyWith(
            rank: i + 1,
          );
        }

        // 캐시 업데이트
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        bool foundCurrentUid = false;
        for (var user in _overallRankings) {
          final effectiveTier = _overallAtBatsCache.containsKey(user.userId)
              ? getBattingTier(user.userId)
              : user.tier;
          _overallTierCache[user.userId] = effectiveTier;
          _overallScoreCache[user.userId] = user.score;
          _overallRankCache[user.userId] = user.rank;
          if (user.userId == currentUid) {
            foundCurrentUid = true;
            _saveMyOverallToLocal(
              user.userId,
              user.score,
              effectiveTier,
              user.rank,
              _selectedSeason,
            );
          }
        }

        // 새 시즌이라 이번 시즌 랭킹에 현재 유저가 없는 경우 -> 티어/점수/순위 초기화
        if (currentUid != null && !foundCurrentUid) {
          _overallTierCache[currentUid] = 'PROSPECT';
          _overallScoreCache[currentUid] = 0;
          _overallRankCache[currentUid] = 0;
          _saveMyOverallToLocal(currentUid, 0, 'PROSPECT', 0, _selectedSeason);
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
      final Map<String, int> teamAtBats = {
        for (final t in teamTotalScores.keys) t: 0,
      };
      final Map<String, int> teamHits = {
        for (final t in teamTotalScores.keys) t: 0,
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

          final rawScore = data['score'] as int;
          final mode = data['mode'] as String? ?? 'normal';
          final score = mode == 'threeOut' && rawScore > 150 ? 150 : rawScore;
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
            final category = data['category'] as String? ?? '';
            final boxMap = data['boxScore'] is Map<String, dynamic>
                ? data['boxScore'] as Map<String, dynamic>
                : null;
            final docAb = category == '일일미션 보상'
                ? 0
                : (data['atBats'] as int? ??
                      boxMap?['atBats'] as int? ??
                      data['totalQuestions'] as int? ??
                      0);
            final docH = category == '일일미션 보상'
                ? 0
                : (data['hits'] as int? ??
                      boxMap?['hits'] as int? ??
                      data['correctAnswers'] as int? ??
                      0);

            if (teamName != null && teamName.isNotEmpty) {
              teamTotalScores[teamName] =
                  (teamTotalScores[teamName] ?? 0) + score;
              teamAtBats[teamName] = (teamAtBats[teamName] ?? 0) + docAb;
              teamHits[teamName] = (teamHits[teamName] ?? 0) + docH;
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
          final rawScore = data['score'] as int;
          final mode = data['mode'] as String? ?? 'normal';
          final score = mode == 'threeOut' && rawScore > 150 ? 150 : rawScore;
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
            final category = data['category'] as String? ?? '';
            final boxMap = data['boxScore'] is Map<String, dynamic>
                ? data['boxScore'] as Map<String, dynamic>
                : null;
            final docAb = category == '일일미션 보상'
                ? 0
                : (data['atBats'] as int? ??
                      boxMap?['atBats'] as int? ??
                      data['totalQuestions'] as int? ??
                      0);
            final docH = category == '일일미션 보상'
                ? 0
                : (data['hits'] as int? ??
                      boxMap?['hits'] as int? ??
                      data['correctAnswers'] as int? ??
                      0);

            if (teamName != null && teamName.isNotEmpty) {
              teamTotalScores[teamName] =
                  (teamTotalScores[teamName] ?? 0) + score;
              teamAtBats[teamName] = (teamAtBats[teamName] ?? 0) + docAb;
              teamHits[teamName] = (teamHits[teamName] ?? 0) + docH;
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
        bool foundCurrentUidInAll = false;
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
            foundCurrentUidInAll = true;
            _saveMyOverallToLocal(
              entry.key,
              total,
              tier,
              rank,
              _selectedSeason,
            );
          }
        }

        // 새 시즌이라 이번 시즌 랭킹에 현재 유저가 없는 경우 초기화
        if (currentUid != null && !foundCurrentUidInAll) {
          _overallTierCache[currentUid] = 'PROSPECT';
          _overallScoreCache[currentUid] = 0;
          _overallRankCache[currentUid] = 0;
          _saveMyOverallToLocal(currentUid, 0, 'PROSPECT', 0, _selectedSeason);
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

      // 타격왕 랭킹(포디움 포함)에 유저 프로필 사진/최신 닉네임 매핑
      if (_battingKingRankings.isNotEmpty) {
        final rankUserMap = {for (final r in _rankings) r.userId: r};
        final List<BattingKingEntry> enriched = [];
        for (int i = 0; i < _battingKingRankings.length; i++) {
          var entry = _battingKingRankings[i];
          final matched = rankUserMap[entry.userId];
          if (matched != null) {
            entry = entry.copyWith(
              name: matched.name,
              teamName: matched.teamName,
              profileUrl: matched.profileUrl,
            );
          } else if (i < 10 &&
              (entry.profileUrl == null || entry.profileUrl!.isEmpty)) {
            try {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(entry.userId)
                  .get();
              final userData = userDoc.data();
              if (userData != null) {
                final nick = userData['userNickName'] as String?;
                entry = entry.copyWith(
                  name: (nick != null && nick.isNotEmpty) ? nick : entry.name,
                  teamName: userData['team'] as String? ?? entry.teamName,
                  profileUrl: userData['profileImage'] as String?,
                );
              }
            } catch (_) {}
          }
          enriched.add(entry);
        }
        _battingKingRankings = enriched;
      }

      final List<RankingTeamModel> tempTeamRankings =
          teamTotalScores.entries
              .map(
                (e) => RankingTeamModel(
                  rank: 0,
                  teamName: e.key,
                  totalScore: e.value,
                  rankChange: 0,
                  totalAtBats: teamAtBats[e.key] ?? 0,
                  totalHits: teamHits[e.key] ?? 0,
                ),
              )
              .toList()
            ..sort((a, b) {
              final avgCmp = b.battingAverage.compareTo(a.battingAverage);
              if (avgCmp != 0) return avgCmp;
              final hitsCmp = b.totalHits.compareTo(a.totalHits);
              if (hitsCmp != 0) return hitsCmp;
              return b.totalScore.compareTo(a.totalScore);
            });

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
      loadDefendingBattingKing();
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
      return overallTeamRankings.firstWhere(
        (team) => team.teamName == teamName,
      );
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
        final data = doc.data();
        final userId = data['userId'] as String;
        if (excludedUserIds.contains(userId)) continue;

        final score = data['score'] as int? ?? 0;
        final boxMap = data['boxScore'] as Map<String, dynamic>?;
        final is3Out = data['isThreeOutMode'] == true;
        final atBats = is3Out
            ? (boxMap?['atBats'] as int? ?? data['atBats'] as int? ?? 0)
            : (data['atBats'] as int? ??
                  boxMap?['atBats'] as int? ??
                  data['totalQuestions'] as int? ??
                  0);
        final hits = is3Out
            ? (boxMap?['hits'] as int? ?? data['hits'] as int? ?? 0)
            : (data['hits'] as int? ??
                  boxMap?['hits'] as int? ??
                  data['correctCount'] as int? ??
                  0);
        final completedAt = data['completedAt'] as Timestamp;
        final seasonId = data['seasonId'] as String? ?? 'legacy';
        String userNickName = data['userNickName'] as String? ?? '';
        if (userNickName.isEmpty) userNickName = '익명';
        final teamName = data['teamName'] as String?;

        seasonData.putIfAbsent(seasonId, () => {});

        if (!seasonData[seasonId]!.containsKey(userId)) {
          seasonData[seasonId]![userId] = {
            'totalScore': score,
            'totalAtBats': atBats,
            'totalHits': hits,
            'completedAt': completedAt,
            'userNickName': userNickName,
            'teamName': teamName,
          };
        } else {
          seasonData[seasonId]![userId]!['totalScore'] =
              (seasonData[seasonId]![userId]!['totalScore'] as int) + score;
          seasonData[seasonId]![userId]!['totalAtBats'] =
              (seasonData[seasonId]![userId]!['totalAtBats'] as int) + atBats;
          seasonData[seasonId]![userId]!['totalHits'] =
              (seasonData[seasonId]![userId]!['totalHits'] as int) + hits;
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
        final bool isBattingSeason =
            seasonId != 'legacy' && seasonId.compareTo('2026_12') >= 0;

        // 2026_12 시즌부터는 규정타석(30타수+) 우선 + 타율 내림차순, 이전 시즌은 점수 내림차순
        final sorted = userScores.entries.toList()
          ..sort((a, b) {
            if (isBattingSeason) {
              final aAb = a.value['totalAtBats'] as int;
              final bAb = b.value['totalAtBats'] as int;
              final aQual = aAb >= 30;
              final bQual = bAb >= 30;
              if (aQual != bQual) return bQual ? 1 : -1;

              final aHits = a.value['totalHits'] as int;
              final bHits = b.value['totalHits'] as int;
              final aAvg = aAb > 0 ? aHits / aAb : 0.0;
              final bAvg = bAb > 0 ? bHits / bAb : 0.0;
              final avgCmp = bAvg.compareTo(aAvg);
              if (avgCmp != 0) return avgCmp;
              final hitsCmp = bHits.compareTo(aHits);
              if (hitsCmp != 0) return hitsCmp;
            }
            return (b.value['totalScore'] as int).compareTo(
              a.value['totalScore'] as int,
            );
          });

        // 2026-04 초과 시즌 → Top 3, 이하 시즌 → 전체
        final bool isRestricted = seasonId.compareTo(_lastOpenSeason) > 0;
        final int limit = isRestricted ? 3 : sorted.length;

        final List<RankingUserModel> seasonRankings = [];

        for (int i = 0; i < sorted.length && i < limit; i++) {
          final userId = sorted[i].key;
          final scoreData = sorted[i].value;
          String? teamName = scoreData['teamName'];
          final int totalScore = scoreData['totalScore'] as int;
          final int totalAtBats = scoreData['totalAtBats'] as int;
          final int totalHits = scoreData['totalHits'] as int;
          final double seasonAvg = totalAtBats > 0
              ? totalHits / totalAtBats
              : 0.0;
          final String tier = isBattingSeason
              ? QuizTierUtils.getTierByBattingStats(totalHits, seasonAvg)
              : QuizTierUtils.getTierName(totalScore);

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
                score: totalScore,
                rankChange: 0,
                profileUrl: userData?['profileImage'],
                completedAt: (scoreData['completedAt'] as Timestamp).toDate(),
                teamName: teamName,
                tier: tier,
                seasonAvg: isBattingSeason ? seasonAvg : null,
                totalHits: isBattingSeason ? totalHits : null,
                totalAtBats: isBattingSeason ? totalAtBats : null,
              ),
            );
          } catch (_) {
            seasonRankings.add(
              RankingUserModel(
                rank: i + 1,
                userId: userId,
                name: scoreData['userNickName'] ?? '익명',
                score: totalScore,
                rankChange: 0,
                profileUrl: null,
                completedAt: (scoreData['completedAt'] as Timestamp).toDate(),
                teamName: teamName,
                tier: tier,
                seasonAvg: isBattingSeason ? seasonAvg : null,
                totalHits: isBattingSeason ? totalHits : null,
                totalAtBats: isBattingSeason ? totalAtBats : null,
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
