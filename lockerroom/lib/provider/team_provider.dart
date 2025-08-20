import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_model.dart';

class TeamProvider with ChangeNotifier {
  String? _team;

  String? get team => _team;

  Future<void> loadTeam(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (doc.exists && doc.data()?['team'] != null) {
      _team = doc['team'];
    }
    notifyListeners();
  }

  final Map<String, List<TeamModel>> _teamList = {
    'team': [
      TeamModel(
        name: '두산베어스',
        symplename: '두산',
        logoPath: 'assets/images/logo/doosan_logo.png',
        symbolPath: 'assets/images/symbol/newlogo2.png',
        color: Doosan,
      ),
      TeamModel(
        name: '삼성라이온즈',
        symplename: '삼성',
        logoPath: 'assets/images/logo/samsung_logo.png',
        symbolPath: 'assets/images/symbol/samsung_symbol.png',
        color: Samsung,
      ),
      TeamModel(
        name: '롯데자이언츠',
        symplename: '롯데',
        logoPath: 'assets/images/logo/lotte_logo.png',
        symbolPath: 'assets/images/symbol/lotte_symbol.png',
        color: Lotte,
      ),
      TeamModel(
        name: '기아타이거즈',
        symplename: '기아',
        logoPath: 'assets/images/logo/kia_logo.png',
        symbolPath: 'assets/images/symbol/kia_symbol.png',
        color: Kia,
      ),
      TeamModel(
        name: 'LG트윈스',
        symplename: 'LG',
        logoPath: 'assets/images/logo/lg_logo.png',
        symbolPath: 'assets/images/symbol/lg_symbol.png',
        color: LG,
      ),
      TeamModel(
        name: 'SSG랜더스',
        symplename: 'SSG',
        logoPath: 'assets/images/logo/ssg_logo.png',
        symbolPath: 'assets/images/symbol/landers_symbol.png',
        color: Landers,
      ),
      TeamModel(
        name: '한화이글스',
        symplename: '한화',
        logoPath: 'assets/images/logo/hanwha_logo.png',
        symbolPath: 'assets/images/symbol/hanwha_symbol.png',
        color: Eagles,
      ),
      TeamModel(
        name: '키움히어로즈',
        symplename: '키움',
        logoPath: 'assets/images/logo/kiwoom_logo.png',
        symbolPath: 'assets/images/symbol/kiwoom_symbol.png',
        color: KIWOOM,
      ),

      TeamModel(
        name: 'NC다이노스',
        symplename: 'NC',
        logoPath: 'assets/images/logo/nc_logo.png',
        symbolPath: 'assets/images/symbol/nc_symbol.png',
        color: NC,
      ),

      TeamModel(
        name: 'KT위즈',
        symplename: 'KT',
        logoPath: 'assets/images/logo/kt_logo.png',
        symbolPath: 'assets/images/symbol/kt_symbol.png',
        color: KT,
      ),
    ],
  };

  TeamModel? _selectedTeam;

  List<TeamModel> getTeam(String category) {
    return _teamList[category] ?? [];
  }

  TeamModel? get selectedTeam => _selectedTeam;

  void selectTeam(TeamModel team) {
    _selectedTeam = team;
    notifyListeners();
  }

  // 팀 이름으로 TeamModel 찾기
  TeamModel? findTeamByName(String name) {
    final teams = _teamList['team'] ?? [];
    try {
      return teams.firstWhere((t) => t.symplename == name);
    } catch (_) {
      return null;
    }
  }

  Future<void> setTeam(String team) async {
    _team = team;
    notifyListeners();
  }
}
