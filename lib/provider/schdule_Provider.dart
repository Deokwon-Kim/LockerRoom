import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/services/schedule_service.dart';

/// UI 표현을 위한 데이터 타입 (날짜 헤더 또는 경기 정보)
enum ScheduleItemType { header, game }

class ScheduleDisplayItem {
  final ScheduleItemType type;
  final String? dateKey; // Header 전용 (예: 2026-03-24)
  final ScheduleModel? game; // Game 전용

  ScheduleDisplayItem.header(this.dateKey)
    : type = ScheduleItemType.header,
      game = null;
  ScheduleDisplayItem.game(this.game)
    : type = ScheduleItemType.game,
      dateKey = null;
}

class ScheduleProvider with ChangeNotifier {
  final Map<String, ScheduleModel> _scheduleMap = {};
  bool _loaded = false;
  bool _isLoading = false;
  StreamSubscription? _subscription;
  StreamSubscription<User?>? _authSubscription;

  // 필터 상태 저장 (실시간 업데이트 시 재가공을 위해 필요)
  DateTime? _lastFilterMonth;
  String? _lastFilterTeam;

  // 가공된 데이터 캐시
  List<ScheduleDisplayItem> _displayItems = [];
  Map<String, int> _dateToIndexMap = {};

  bool get loaded => _loaded;
  List<ScheduleModel> get allSchedules => _scheduleMap.values.toList();
  List<ScheduleDisplayItem> get displayItems => _displayItems;

  ScheduleModel? getById(String id) => _scheduleMap[id];

  /// 특정 월과 팀에 맞는 데이터를 필터링하고 그룹화합니다.
  void updateDisplayItems(DateTime month, String? teamSympleName) {
    _lastFilterMonth = month;
    _lastFilterTeam = teamSympleName;
    _processData();
  }

  /// 내부 데이터 가공 로직
  void _processData() {
    if (!_loaded || _lastFilterMonth == null) return;

    final month = _lastFilterMonth!;
    final teamSympleName = _lastFilterTeam;

    final List<ScheduleDisplayItem> newItems = [];
    final Map<String, int> newIndexMap = {};

    // 1. 경기 필터링
    final filteredMatches = _scheduleMap.values.where((s) {
      final isCorrectMonth =
          s.dateTimeKst.year == month.year &&
          s.dateTimeKst.month == month.month;
      if (!isCorrectMonth) return false;

      if (teamSympleName == null) return true;
      return s.homeTeam == teamSympleName || s.awayTeam == teamSympleName;
    }).toList();

    if (filteredMatches.isEmpty) {
      _displayItems = [];
      _dateToIndexMap = {};
      notifyListeners();
      return;
    }

    // 2. 날짜별 그룹화
    final Map<String, List<ScheduleModel>> grouped = {};
    for (var m in filteredMatches) {
      final key =
          "${m.dateTimeKst.year}-${m.dateTimeKst.month.toString().padLeft(2, '0')}-${m.dateTimeKst.day.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(key, () => []).add(m);
    }

    // 3. 날짜순 정렬 및 리스트 생성
    final sortedKeys = grouped.keys.toList()..sort();
    for (var key in sortedKeys) {
      newIndexMap[key] = newItems.length;
      newItems.add(ScheduleDisplayItem.header(key));

      final games = grouped[key]!;
      games.sort((a, b) => a.dateTimeKst.compareTo(b.dateTimeKst));
      for (var game in games) {
        newItems.add(ScheduleDisplayItem.game(game));
      }
    }

    _displayItems = newItems;
    _dateToIndexMap = newIndexMap;
    notifyListeners();
  }

  int getIndexForDate(String dateKey) => _dateToIndexMap[dateKey] ?? -1;

  Future<void> load() async {
    if (_loaded || _isLoading) return;
    _isLoading = true;

    // 1. 로그인 상태에 따라 Firestore 실시간 리스너 즉시 연결 (CSV 대기 없이 병렬 시작)
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _subscribeToFirestoreGames();
      } else {
        _subscription?.cancel();
        _subscription = null;
      }
    });

    try {
      // 2. 올해(2026) 시즌 CSV만 우선 로드해 홈 일정 위젯 즉시 표시
      final currentList = await ScheduleService().loadSchedules(
        assetPaths: const ['assets/schedules/kbo_2026.csv'],
      );
      for (final s in currentList) {
        _scheduleMap.putIfAbsent(s.gameId, () => s);
      }
    } catch (e) {
      debugPrint('Error loading 2026 static schedules: $e');
    } finally {
      // 어떤 경우에도 무한 로딩에 빠지지 않도록 로드 완료 보장
      _loaded = true;
      _isLoading = false;
      _processData();
      notifyListeners();
    }

    // 3. 과거 연도(2010~2025) CSV는 백그라운드에서 추가 로드 (Firestore 최신값 보존)
    unawaited(_loadPastSeasonSchedules());
  }

  Future<void> _loadPastSeasonSchedules() async {
    try {
      final pastPaths = ScheduleService.defaultAssetPaths
          .where((p) => !p.endsWith('kbo_2026.csv'))
          .toList();
      if (pastPaths.isEmpty) return;

      final pastList = await ScheduleService().loadSchedules(
        assetPaths: pastPaths,
      );
      bool added = false;
      for (final s in pastList) {
        if (!_scheduleMap.containsKey(s.gameId)) {
          _scheduleMap[s.gameId] = s;
          added = true;
        }
      }
      if (added) {
        _processData();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading past static schedules: $e');
    }
  }

  void _subscribeToFirestoreGames() {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('games')
        .snapshots()
        .listen(
          (snapshot) {
            bool hasChanged = false;
            for (var doc in snapshot.docs) {
              try {
                final model = ScheduleModel.fromFirestore(doc);
                _scheduleMap[model.gameId] = model;
                hasChanged = true;
              } catch (e) {
                debugPrint('Error parsing game doc ${doc.id}: $e');
              }
            }
            _loaded = true;
            if (hasChanged) {
              _processData(); // 데이터 수신 시 UI 리스트 재가공
            }
            // 스냅샷 수신 시 무조건 알림 (데이터 변경 또는 에러 시에도 로딩 취소를 위해)
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Firestore Schedule Subscription Error: $error');
            // 에러 발생 시에도 무조건 로딩은 끝난 것으로 간주 (실패 화면이라도 보여주기 위해)
            _loaded = true;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
