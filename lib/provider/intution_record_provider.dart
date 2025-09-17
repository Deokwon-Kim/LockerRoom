import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/services/schedule_service.dart';
import 'package:provider/provider.dart';

class IntutionRecordProvider extends ChangeNotifier {
  final TextEditingController myScoreController = TextEditingController();
  final TextEditingController oppScoreContreller = TextEditingController();

  bool _isLoading = true;
  bool _saving = false;

  ScheduleModel? _todayGame;
  String? _myTeamSymple;
  String? _todayStr;

  bool get isLoding => _isLoading;
  bool get saving => _saving;
  ScheduleModel? get todayGame => _todayGame;
  String? get myTeamSymple => _myTeamSymple;
  String? get todayStr => _todayStr;

  @override
  void dispose() {
    myScoreController.dispose();
    oppScoreContreller.dispose();
    super.dispose();
  }

  String _yyyyMmDd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String? _normalizeToCsvTeamName(BuildContext context, String saved) {
    final tp = context.read<TeamProvider>();
    final teams = tp.getTeam('team');
    for (final t in teams) {
      if (t.symplename == saved || t.name == saved) {
        return t.symplename;
      }
    }
    return null;
  }

  Future<void> init(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    // 응원팀 불러오기
    final teamProvider = context.read<TeamProvider>();
    if (teamProvider.team == null) {
      await teamProvider.loadTeam(user.uid);
    }
    final savedTeam = teamProvider.team;
    final symple = savedTeam == null
        ? null
        : _normalizeToCsvTeamName(context, savedTeam);
    final today = _yyyyMmDd(DateTime.now());
    ScheduleModel? match;

    if (symple != null) {
      final schedules = await ScheduleService().loadSchedules();
      final todays = schedules.where((s) => _yyyyMmDd(s.dateTimeKst) == today);

      final filtered = todays.where(
        (s) => s.homeTeam == symple || s.awayTeam == symple,
      );

      match = filtered.isNotEmpty ? filtered.first : null;
    }

    // 기존기록 있으면 불러오기
    if (match != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('attendances')
          .doc(match.gameId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final int? myScore = data['myScroe'] is int
            ? data['myScore'] as int
            : int.tryParse('${data['myScroe']}');
        final int? oppScore = data['opponentScore'] is int
            ? data['opponentScore'] as int
            : int.tryParse('${data['opponentScore']}');
        if (myScore != null) myScoreController.text = myScore.toString();
        if (oppScore != null) oppScoreContreller.text = oppScore.toString();
      }
    }

    _todayStr = today;
    _myTeamSymple = symple;
    _todayGame = match;
    _isLoading = false;
    notifyListeners();
  }

  String? validateScore(String? v) {
    if (v == null || v.trim().isEmpty) return '필수 입력';
    final n = int.tryParse(v);
    if (n == null || n < 0 || n > 99) return '0~99 사이 숫자';
    return null;
  }

  Future<bool> save(BuildContext context) async {
    if (_todayGame == null || _myTeamSymple == null || _todayStr == null)
      return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    if (validateScore(myScoreController.text) != null ||
        validateScore(oppScoreContreller.text) != null) {
      return false;
    }

    final myScore = int.parse(myScoreController.text);
    final oppScore = int.parse(oppScoreContreller.text);
    final g = _todayGame!;

    _saving = true;
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('attendances')
          .doc(g.gameId)
          .set({
            'season': g.season,
            'gameId': g.gameId,
            'date': _yyyyMmDd(g.dateTimeKst),
            'time':
                '${g.dateTimeKst.hour.toString().padLeft(2, '0')}:${g.dateTimeKst.minute.toString().padLeft(2, '0')}',
            'stadium': g.stadium,
            'homeTeam': g.homeTeam,
            'awayTeam': g.awayTeam,
            'myTeam': _myTeamSymple,
            'myScore': myScore,
            'opponentScore': oppScore,
            'createdAt': FieldValue.serverTimestamp(),
            'updateAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
